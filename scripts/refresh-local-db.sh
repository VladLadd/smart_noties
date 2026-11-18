#!/usr/bin/env bash
# Запускается на Mac. Серверная БД используется только для чтения.
set -Eeuo pipefail
umask 077

usage() {
  cat <<'HELP'
Обновить локальную БД актуальными данными с сервера:
  bash scripts/refresh-local-db.sh

Восстановить уже скачанный дамп:
  bash scripts/refresh-local-db.sh --from-dump /path/to/database.dump

Настройки через переменные окружения:
  SSH_HOST=86.110.191.206 SSH_PORT=2222 SSH_USER=ladd
  SSH_KEY=$HOME/.ssh/ladd_server_ed25519 REMOTE_DB=smart_noties
  LOCAL_CONTAINER=backend-db-1 LOCAL_DB=ladd_db LOCAL_USER=ladd_dev
  BACKUP_ROOT=$HOME/Backups/smart-noties

Пароль sudo вводится в терминале. Локальная БД заменяется целиком.
Старые данные остаются в дампе и отдельной локальной БД.
Файлы uploads этим скриптом не копируются.
HELP
}

die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
source_dump=''
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --from-dump)
    [[ $# == 2 && -f "$2" ]] || die 'Укажите существующий файл дампа.'
    source_dump="$2" ;;
  '') [[ $# == 0 ]] || die 'Неизвестные аргументы.' ;;
  *) usage; exit 1 ;;
esac

SSH_HOST=${SSH_HOST:-86.110.191.206}
SSH_PORT=${SSH_PORT:-2222}
SSH_USER=${SSH_USER:-ladd}
SSH_KEY=${SSH_KEY:-$HOME/.ssh/ladd_server_ed25519}
REMOTE_DB=${REMOTE_DB:-smart_noties}
LOCAL_CONTAINER=${LOCAL_CONTAINER:-backend-db-1}
LOCAL_DB=${LOCAL_DB:-ladd_db}
LOCAL_USER=${LOCAL_USER:-ladd_dev}
BACKUP_ROOT=${BACKUP_ROOT:-$HOME/Backups/smart-noties}

for value in "$LOCAL_DB" "$LOCAL_USER" "$REMOTE_DB"; do
  [[ "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ && ${#value} -le 63 ]] ||
    die 'Некорректное имя БД или пользователя PostgreSQL.'
done
case "$LOCAL_DB" in
  postgres|template0|template1) die 'Нельзя заменять служебную БД PostgreSQL.' ;;
esac
for tool in docker shasum; do
  command -v "$tool" >/dev/null || die "Не найдена команда $tool."
done
if [[ -z "$source_dump" ]]; then
  [[ -t 0 ]] || die 'Запустите скрипт в Terminal: понадобится пароль sudo.'
  [[ -r "$SSH_KEY" ]] || die "Не найден SSH-ключ: $SSH_KEY"
  for tool in ssh scp; do
    command -v "$tool" >/dev/null || die "Не найдена команда $tool."
  done
fi
# Не допускаем случайного восстановления в удалённый Docker context.
endpoint=$(docker context inspect --format '{{.Endpoints.docker.Host}}')
[[ "$endpoint" == unix://* ]] || die 'Нужен локальный Docker context с unix-сокетом.'
docker info >/dev/null 2>&1 || die 'Запустите Docker Desktop и повторите команду.'
docker inspect "$LOCAL_CONTAINER" >/dev/null 2>&1 || die "Не найден контейнер $LOCAL_CONTAINER."
docker start "$LOCAL_CONTAINER" >/dev/null
ready=false
for ((i=0; i<60; i++)); do
  if docker exec "$LOCAL_CONTAINER" pg_isready -U "$LOCAL_USER" -d "$LOCAL_DB" >/dev/null 2>&1; then
    ready=true; break
  fi
  sleep 1
done
[[ "$ready" == true ]] || die 'Локальный PostgreSQL не запустился за 60 секунд.'

mkdir -p "$BACKUP_ROOT"
work=$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%d_%H%M%S)_XXXXXX")
stage="sn_refresh_$(date +%Y%m%d%H%M%S)_$$"
previous="sn_before_$(date +%Y%m%d%H%M%S)_$$"
stage_created=false
remote_dir=''
ssh_options=(-o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15
  -o "ControlPath=$work/ssh.sock" -i "$SSH_KEY" -p "$SSH_PORT")
target="$SSH_USER@$SSH_HOST"
psql_local() {
  docker exec -i "$LOCAL_CONTAINER" psql -X -U "$LOCAL_USER" -d postgres -v ON_ERROR_STOP=1 "$@"
}
cleanup() {
  result=$?
  trap - EXIT
  if [[ "$stage_created" == true ]]; then
    docker exec "$LOCAL_CONTAINER" dropdb -U "$LOCAL_USER" --if-exists "$stage" >/dev/null 2>&1 || true
  fi
  if [[ "$remote_dir" == /tmp/smart-notes-export.* && "$remote_dir" != *[!a-zA-Z0-9_./-]* ]]; then
    ssh "${ssh_options[@]}" "$target" "rm -rf -- '$remote_dir'" >/dev/null 2>&1 || true
  fi
  if [[ -S "$work/ssh.sock" ]]; then
    ssh "${ssh_options[@]}" -O exit "$target" >/dev/null 2>&1 || true
  fi
  if [[ $result != 0 ]]; then
    printf '\nОбновление не завершено. Резервные файлы: %s\n' "$work" >&2
  fi
  exit "$result"
}
trap cleanup EXIT

printf 'Сохраняю текущую локальную БД: %s\n' "$work/local-before-refresh.dump"
docker exec "$LOCAL_CONTAINER" pg_dump -U "$LOCAL_USER" -d "$LOCAL_DB" \
  -Fc --no-owner --no-acl > "$work/local-before-refresh.dump"
docker exec -i "$LOCAL_CONTAINER" pg_restore --list < "$work/local-before-refresh.dump" >/dev/null

if [[ -n "$source_dump" ]]; then
  cp "$source_dump" "$work/server-current.dump"
else
  ssh "${ssh_options[@]}" -M -f -N "$target"
  remote_dir=$(ssh "${ssh_options[@]}" "$target" 'umask 077; mktemp -d /tmp/smart-notes-export.XXXXXXXX')
  [[ "$remote_dir" == /tmp/smart-notes-export.* && "$remote_dir" != *[!a-zA-Z0-9_./-]* ]] || die 'Некорректный путь временного каталога на сервере.'
  # Скрипт не содержит паролей; sudo читает пароль с удалённого терминала.
  cat > "$work/export-server.sh" <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail
umask 077
directory=$1
database=$2
sudo -v
sudo -u postgres /usr/bin/pg_dump -Fc --no-owner --no-acl -d "$database" > "$directory/server.dump"
/usr/bin/pg_restore --list "$directory/server.dump" >/dev/null
sha256sum "$directory/server.dump" | cut -d ' ' -f 1 > "$directory/server.sha256"
REMOTE
  scp_options=(-q -o BatchMode=yes -o ConnectTimeout=20 -o "ControlPath=$work/ssh.sock" -i "$SSH_KEY" -P "$SSH_PORT")
  scp "${scp_options[@]}" "$work/export-server.sh" "$target:$remote_dir/export.sh"
  printf '\nВведите пароль sudo для пользователя %s на сервере:\n' "$SSH_USER"
  ssh -t "${ssh_options[@]}" "$target" "bash '$remote_dir/export.sh' '$remote_dir' '$REMOTE_DB'"
  scp "${scp_options[@]}" "$target:$remote_dir/server.dump" "$work/server-current.dump"
  scp "${scp_options[@]}" "$target:$remote_dir/server.sha256" "$work/server.sha256"
  actual=$(shasum -a 256 "$work/server-current.dump" | cut -d ' ' -f 1)
  [[ "$actual" == "$(tr -d '\r\n' < "$work/server.sha256")" ]] || die 'Контрольная сумма скачанного дампа не совпала.'
fi

printf '\nПроверяю дамп в отдельной локальной БД...\n'
docker exec -i "$LOCAL_CONTAINER" pg_restore --list < "$work/server-current.dump" > "$work/server-archive-list.txt"
docker exec "$LOCAL_CONTAINER" createdb -U "$LOCAL_USER" -T template0 "$stage"
stage_created=true
docker exec -i "$LOCAL_CONTAINER" pg_restore -U "$LOCAL_USER" -d "$stage" \
  --no-owner --no-privileges --exit-on-error --single-transaction < "$work/server-current.dump"
# Эти запросы также проверяют наличие основных таблиц и доступность данных.
docker exec "$LOCAL_CONTAINER" psql -X -U "$LOCAL_USER" -d "$stage" -v ON_ERROR_STOP=1 \
  -c 'SELECT count(*) AS users FROM public.users; SELECT count(*) AS notes FROM public.notes;'

printf 'Заменяю локальную БД. Текущие локальные подключения будут переподключены.\n'
# Переключение имён транзакционное: при ошибке сохраняются прежние имена БД.
# Старую БД не удаляем; дополнительно уже сохранён её pg_dump.
psql_local <<SQL
BEGIN;
SET LOCAL lock_timeout = '15s';
ALTER DATABASE "$LOCAL_DB" WITH ALLOW_CONNECTIONS false;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
  WHERE datname = '$LOCAL_DB' AND pid <> pg_backend_pid();
ALTER DATABASE "$LOCAL_DB" RENAME TO "$previous";
ALTER DATABASE "$stage" RENAME TO "$LOCAL_DB";
ALTER DATABASE "$LOCAL_DB" WITH ALLOW_CONNECTIONS true;
COMMIT;
SQL
stage_created=false
printf '\nГотово: локальная БД %s обновлена.\nРезервные файлы: %s\nПредыдущая БД сохранена как: %s (подключения отключены).\n' "$LOCAL_DB" "$work" "$previous"
printf 'Перенесена БД; каталог uploads на сервере не копировался.\n'
