import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/admin_user_model.dart';
import 'models/nfc_key_model.dart';
import 'models/nfc_token_request_model.dart';
import 'services/auth_service.dart';
import 'services/nfc_admin_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SmartNotesAdminApp());
}

class SmartNotesAdminApp extends StatefulWidget {
  const SmartNotesAdminApp({super.key});

  @override
  State<SmartNotesAdminApp> createState() => _SmartNotesAdminAppState();
}

class _SmartNotesAdminAppState extends State<SmartNotesAdminApp> {
  AuthUser? _user;
  String? _token;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _token == null || _user == null
          ? _AdminLoginScreen(onLoggedIn: _onLoggedIn)
          : _AdminShell(
              user: _user!,
              token: _token!,
              onLogout: _logout,
            ),
    );
  }

  void _onLoggedIn(String token, AuthUser user) {
    setState(() {
      _token = token;
      _user = user;
    });
  }

  void _logout() {
    setState(() {
      _token = null;
      _user = null;
    });
  }
}

class _AdminLoginScreen extends StatefulWidget {
  final void Function(String token, AuthUser user) onLoggedIn;

  const _AdminLoginScreen({required this.onLoggedIn});

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите email и пароль');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _authService.login(email: email, password: password);
      if (!mounted) return;
      widget.onLoggedIn(result.token, result.user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'NFC Admin',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Выпуск ссылок для NFC-карт smart_noties',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.red[700])),
                ],
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _login,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminShell extends StatefulWidget {
  final AuthUser user;
  final String token;
  final VoidCallback onLogout;

  const _AdminShell({
    required this.user,
    required this.token,
    required this.onLogout,
  });

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _section = 0;

  bool get _isAdmin => widget.user.role == 'admin';

  @override
  Widget build(BuildContext context) {
    final sections = <_ShellSection>[
      _ShellSection(
        icon: Icons.credit_card,
        label: 'Мои карты',
        child: _MyKeysPanel(token: widget.token),
      ),
    ];
    if (_isAdmin) {
      sections.add(
        _ShellSection(
          icon: Icons.approval_outlined,
          label: 'Запросы NFC',
          child: _TokenRequestsPanel(token: widget.token),
        ),
      );
      sections.add(
        _ShellSection(
          icon: Icons.group_outlined,
          label: 'Пользователи',
          child: _AdminUsersPanel(token: widget.token),
        ),
      );
    }
    final selected = _section.clamp(0, sections.length - 1).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Row(
        children: [
          Container(
            width: 248,
            color: Colors.white,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      'NFC Admin',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _UserBadge(user: widget.user),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < sections.length; i++)
                    _NavItem(
                      icon: sections[i].icon,
                      label: sections[i].label,
                      selected: selected == i,
                      onTap: () => setState(() => _section = i),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Выйти',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: sections[selected].child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellSection {
  final IconData icon;
  final String label;
  final Widget child;

  const _ShellSection({
    required this.icon,
    required this.label,
    required this.child,
  });
}

class _UserBadge extends StatelessWidget {
  final AuthUser user;

  const _UserBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email.isNotEmpty ? user.email : 'Без email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  user.role,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? Colors.white : Colors.black87),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyKeysPanel extends StatefulWidget {
  final String token;

  const _MyKeysPanel({required this.token});

  @override
  State<_MyKeysPanel> createState() => _MyKeysPanelState();
}

class _MyKeysPanelState extends State<_MyKeysPanel> {
  final _service = NfcAdminService();
  final _nameCtrl = TextEditingController();
  List<NfcKey> _keys = const [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keys = await _service.fetchMyKeys(token: widget.token);
      if (!mounted) return;
      setState(() => _keys = keys);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await _service.createMyKey(
        token: widget.token,
        name: _nameCtrl.text,
      );
      if (!mounted) return;
      _nameCtrl.clear();
      await _showCreatedKeyDialog(context, created);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _revoke(NfcKey key) async {
    final confirmed = await _confirmRevoke(context, key);
    if (confirmed != true || !mounted) return;

    try {
      await _service.revokeMyKey(token: widget.token, keyId: key.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      title: 'Мои NFC-карты',
      subtitle: 'Ссылки для карт, которые открывают ваши скрытые заметки.',
      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CreateKeyBar(
            controller: _nameCtrl,
            loading: _creating,
            onCreate: _create,
          ),
          const SizedBox(height: 16),
          if (_error != null) _ErrorBanner(message: _error!),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _NfcKeysTable(
                keys: _keys,
                onRevoke: _revoke,
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminUsersPanel extends StatefulWidget {
  final String token;

  const _AdminUsersPanel({required this.token});

  @override
  State<_AdminUsersPanel> createState() => _AdminUsersPanelState();
}

class _AdminUsersPanelState extends State<_AdminUsersPanel> {
  final _service = NfcAdminService();
  final _searchCtrl = TextEditingController();
  final _keyNameCtrl = TextEditingController();
  List<AdminUser> _users = const [];
  List<NfcKey> _selectedKeys = const [];
  AdminUser? _selectedUser;
  bool _loadingUsers = true;
  bool _loadingKeys = false;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _keyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loadingUsers = true;
      _error = null;
    });
    try {
      final users = await _service.searchUsers(
        token: widget.token,
        query: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        if (_selectedUser != null &&
            !users.any((user) => user.id == _selectedUser!.id)) {
          _selectedUser = null;
          _selectedKeys = const [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _selectUser(AdminUser user) async {
    setState(() {
      _selectedUser = user;
      _selectedKeys = const [];
      _loadingKeys = true;
      _error = null;
    });
    try {
      final keys = await _service.fetchUserKeys(
        token: widget.token,
        userId: user.id,
      );
      if (!mounted) return;
      setState(() => _selectedKeys = keys);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingKeys = false);
    }
  }

  Future<void> _createForSelectedUser() async {
    final user = _selectedUser;
    if (user == null) return;

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await _service.createUserKey(
        token: widget.token,
        userId: user.id,
        name: _keyNameCtrl.text,
      );
      if (!mounted) return;
      _keyNameCtrl.clear();
      await _showCreatedKeyDialog(context, created);
      await _selectUser(user);
      await _search();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _revokeForSelectedUser(NfcKey key) async {
    final user = _selectedUser;
    if (user == null) return;

    final confirmed = await _confirmRevoke(context, key);
    if (confirmed != true || !mounted) return;

    try {
      await _service.revokeUserKey(
        token: widget.token,
        userId: user.id,
        keyId: key.id,
      );
      await _selectUser(user);
      await _search();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      title: 'Пользователи',
      subtitle: 'Выпуск NFC-карт для чужих аккаунтов без доступа к заметкам.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Поиск по email, телефону или имени',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Искать',
                onPressed: _loadingUsers ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) _ErrorBanner(message: _error!),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: _UsersList(
                    users: _users,
                    selectedUser: _selectedUser,
                    loading: _loadingUsers,
                    onSelect: _selectUser,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SelectedUserKeysPanel(
                    user: _selectedUser,
                    keys: _selectedKeys,
                    loading: _loadingKeys,
                    creating: _creating,
                    keyNameController: _keyNameCtrl,
                    onCreate: _createForSelectedUser,
                    onRevoke: _revokeForSelectedUser,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenRequestsPanel extends StatefulWidget {
  final String token;

  const _TokenRequestsPanel({required this.token});

  @override
  State<_TokenRequestsPanel> createState() => _TokenRequestsPanelState();
}

class _TokenRequestsPanelState extends State<_TokenRequestsPanel> {
  final _service = NfcAdminService();
  List<NfcTokenRequest> _requests = const [];
  String _status = 'pending';
  String? _actingId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _service.fetchAdminTokenRequests(
        token: widget.token,
        status: _status,
      );
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(NfcTokenRequest request) async {
    setState(() {
      _actingId = request.id;
      _error = null;
    });
    try {
      await _service.approveTokenRequest(
        token: widget.token,
        requestId: request.id,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC-токен выдан пользователю')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _reject(NfcTokenRequest request) async {
    setState(() {
      _actingId = request.id;
      _error = null;
    });
    try {
      await _service.rejectTokenRequest(
        token: widget.token,
        requestId: request.id,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      title: 'Запросы NFC',
      subtitle: 'Одобрение пользовательских запросов на выдачу NFC-токена.',
      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Статус',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Ожидают')),
                  DropdownMenuItem(value: 'approved', child: Text('Одобрены')),
                  DropdownMenuItem(value: 'consumed', child: Text('Записаны')),
                  DropdownMenuItem(value: 'rejected', child: Text('Отклонены')),
                  DropdownMenuItem(value: '', child: Text('Все')),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _status = value ?? 'pending');
                        _load();
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) _ErrorBanner(message: _error!),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _TokenRequestsTable(
                requests: _requests,
                actingId: _actingId,
                onApprove: _approve,
                onReject: _reject,
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  const _PanelFrame({
    required this.title,
    required this.subtitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateKeyBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onCreate;

  const _CreateKeyBar({
    required this.controller,
    required this.loading,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Название карты',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onSubmitted: (_) => onCreate(),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: loading ? null : onCreate,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_card),
          label: const Text('Создать'),
        ),
      ],
    );
  }
}

class _UsersList extends StatelessWidget {
  final List<AdminUser> users;
  final AdminUser? selectedUser;
  final bool loading;
  final ValueChanged<AdminUser> onSelect;

  const _UsersList({
    required this.users,
    required this.selectedUser,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (users.isEmpty) return const _EmptyState(text: 'Пользователи не найдены');

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        final selected = selectedUser?.id == user.id;
        return Material(
          color: selected ? Colors.black : const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelect(user),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: selected ? Colors.white : Colors.black12,
                    child: Text(
                      user.id.toString(),
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email.isNotEmpty ? user.email : 'Без email',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userSubtitle(user),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white70 : Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SmallBadge(
                    text: '${user.nfcKeysCount}',
                    dark: selected,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _userSubtitle(AdminUser user) {
    final parts = [
      if (user.name.isNotEmpty) user.name,
      if (user.phone.isNotEmpty) user.phone,
      user.role,
    ];
    return parts.join(' · ');
  }
}

class _SelectedUserKeysPanel extends StatelessWidget {
  final AdminUser? user;
  final List<NfcKey> keys;
  final bool loading;
  final bool creating;
  final TextEditingController keyNameController;
  final VoidCallback onCreate;
  final ValueChanged<NfcKey> onRevoke;

  const _SelectedUserKeysPanel({
    required this.user,
    required this.keys,
    required this.loading,
    required this.creating,
    required this.keyNameController,
    required this.onCreate,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final selected = user;
    if (selected == null) {
      return const _EmptyState(text: 'Выберите пользователя слева');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.email.isNotEmpty ? selected.email : 'Без email',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID ${selected.id} · ${selected.role}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CreateKeyBar(
          controller: keyNameController,
          loading: creating,
          onCreate: onCreate,
        ),
        const SizedBox(height: 16),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: _NfcKeysTable(
              keys: keys,
              onRevoke: onRevoke,
            ),
          ),
      ],
    );
  }
}

class _NfcKeysTable extends StatelessWidget {
  final List<NfcKey> keys;
  final ValueChanged<NfcKey> onRevoke;

  const _NfcKeysTable({
    required this.keys,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) return const _EmptyState(text: 'NFC-карт пока нет');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F5F7)),
          columns: const [
            DataColumn(label: Text('Название')),
            DataColumn(label: Text('Tag ID')),
            DataColumn(label: Text('Статус')),
            DataColumn(label: Text('Последнее касание')),
            DataColumn(label: Text('Создана')),
            DataColumn(label: Text('')),
          ],
          rows: keys
              .map(
                (key) => DataRow(
                  cells: [
                    DataCell(
                      Text(key.name.isNotEmpty ? key.name : 'NFC-карта'),
                    ),
                    DataCell(SelectableText(key.tagId)),
                    DataCell(_StatusBadge(active: key.isActive)),
                    DataCell(Text(_fmtDate(key.lastUsedAt))),
                    DataCell(Text(_fmtDate(key.createdAt))),
                    DataCell(
                      IconButton(
                        tooltip: 'Отозвать',
                        onPressed: key.isActive ? () => onRevoke(key) : null,
                        icon: const Icon(Icons.block, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TokenRequestsTable extends StatelessWidget {
  final List<NfcTokenRequest> requests;
  final String? actingId;
  final ValueChanged<NfcTokenRequest> onApprove;
  final ValueChanged<NfcTokenRequest> onReject;

  const _TokenRequestsTable({
    required this.requests,
    required this.actingId,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const _EmptyState(text: 'Заявок нет');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F5F7)),
          columns: const [
            DataColumn(label: Text('Пользователь')),
            DataColumn(label: Text('Название')),
            DataColumn(label: Text('Статус')),
            DataColumn(label: Text('Создана')),
            DataColumn(label: Text('Одобрена')),
            DataColumn(label: Text('')),
          ],
          rows: requests
              .map(
                (request) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 260,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.userEmail.isNotEmpty
                                  ? request.userEmail
                                  : 'ID ${request.userId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _requestUserSubtitle(request),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(request.title)),
                    DataCell(_TokenRequestStatusBadge(status: request.status)),
                    DataCell(Text(_fmtDate(request.createdAt))),
                    DataCell(Text(_fmtDate(request.approvedAt))),
                    DataCell(
                      _TokenRequestActions(
                        request: request,
                        busy: actingId == request.id,
                        onApprove: onApprove,
                        onReject: onReject,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _requestUserSubtitle(NfcTokenRequest request) {
    final parts = [
      if (request.userName.isNotEmpty) request.userName,
      if (request.userPhone.isNotEmpty) request.userPhone,
    ];
    return parts.isEmpty ? 'Пользователь' : parts.join(' · ');
  }
}

class _TokenRequestActions extends StatelessWidget {
  final NfcTokenRequest request;
  final bool busy;
  final ValueChanged<NfcTokenRequest> onApprove;
  final ValueChanged<NfcTokenRequest> onReject;

  const _TokenRequestActions({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (!request.isPending) {
      return const SizedBox(width: 96, child: Text('—'));
    }
    if (busy) {
      return const SizedBox(
        width: 96,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      width: 96,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Одобрить',
            onPressed: () => onApprove(request),
            icon: const Icon(Icons.check_circle, color: Colors.green),
          ),
          IconButton(
            tooltip: 'Отклонить',
            onPressed: () => onReject(request),
            icon: const Icon(Icons.cancel, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _TokenRequestStatusBadge extends StatelessWidget {
  final String status;

  const _TokenRequestStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      'approved' => 'Одобрена',
      'rejected' => 'Отклонена',
      'consumed' => 'Записана',
      _ => 'Ожидает',
    };
    final color = switch (status) {
      'approved' => Colors.green[700],
      'rejected' => Colors.red[700],
      'consumed' => Colors.blueGrey[700],
      _ => Colors.orange[800],
    };
    return _SmallBadge(text: text, color: color);
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return _SmallBadge(
      text: active ? 'Активна' : 'Отозвана',
      color: active ? Colors.green[700] : Colors.red[700],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final bool dark;
  final Color? color;

  const _SmallBadge({
    required this.text,
    this.dark = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (dark ? Colors.white24 : Colors.black12);
    final fg = dark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == null ? fg : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red[800])),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[700], fontSize: 16),
      ),
    );
  }
}

Future<void> _showCreatedKeyDialog(
  BuildContext context,
  NfcKeyCreateResult created,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('NFC-ссылка создана'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Секрет показывается только сейчас. Запишите эту строку '
              'на NFC-карту как URI/URL record.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: SelectableText(created.ndefUri),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Закрыть'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: created.ndefUri));
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Ссылка скопирована')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Копировать'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmRevoke(BuildContext context, NfcKey key) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Отозвать NFC-карту?'),
      content: Text(
        'Карта «${key.name.isNotEmpty ? key.name : key.tagId}» перестанет '
        'открывать скрытые заметки.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Отозвать', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

String _fmtDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final date = [
    local.day.toString().padLeft(2, '0'),
    local.month.toString().padLeft(2, '0'),
    local.year.toString(),
  ].join('.');
  final time = [
    local.hour.toString().padLeft(2, '0'),
    local.minute.toString().padLeft(2, '0'),
  ].join(':');
  return '$date $time';
}
