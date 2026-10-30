import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../models/nfc_token_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notes_provider.dart';
import '../services/nfc_admin_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nfcService = NfcAdminService();
  List<NfcTokenRequest> _tokenRequests = const [];
  bool _loadingRequests = true;
  bool _requestingToken = false;
  String? _nfcError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTokenRequests());
  }

  Future<void> _loadTokenRequests() async {
    final token = context.read<AuthProvider>().token;
    final strings = context.readStrings;
    if (token == null || token.isEmpty) {
      setState(() {
        _loadingRequests = false;
        _nfcError = strings.needAuth;
      });
      return;
    }

    setState(() {
      _loadingRequests = true;
      _nfcError = null;
    });
    try {
      final requests = await _nfcService.fetchMyTokenRequests(token: token);
      if (!mounted) return;
      setState(() => _tokenRequests = requests);
    } catch (e) {
      if (!mounted) return;
      setState(() => _nfcError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _requestToken() async {
    final token = context.read<AuthProvider>().token;
    final strings = context.readStrings;
    if (token == null || token.isEmpty || _requestingToken) return;

    final name = await _askTokenName(context);
    if (!mounted || name == null) return;

    setState(() {
      _requestingToken = true;
      _nfcError = null;
    });
    try {
      await _nfcService.createMyTokenRequest(token: token, name: name);
      await _loadTokenRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.requestSentToAdmin)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _nfcError = e.toString());
    } finally {
      if (mounted) setState(() => _requestingToken = false);
    }
  }

  Future<void> _copyToken(NfcTokenRequest request) async {
    if (request.ndefUri.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: request.ndefUri));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.readStrings.nfcTokenCopied)),
    );
  }

  Future<void> _consumeToken(NfcTokenRequest request) async {
    final token = context.read<AuthProvider>().token;
    final strings = context.readStrings;
    if (token == null || token.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.hideTokenQuestion),
        content: Text(strings.hideTokenMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.hide),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _nfcService.consumeMyTokenRequest(
        token: token,
        requestId: request.id,
      );
      await _loadTokenRequests();
    } catch (e) {
      if (!mounted) return;
      setState(() => _nfcError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().email;
    final notesCount = context.watch<NotesProvider>().notes.length;
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.profile)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: CircleAvatar(
                  radius: 44,
                  child: Icon(Icons.person, size: 48),
                ),
              ),
              const SizedBox(height: 32),
              _InfoTile(
                icon: Icons.email_outlined,
                label: strings.email,
                value: (email != null && email.isNotEmpty) ? email : '—',
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.notes_outlined,
                label: strings.notesCount,
                value: '$notesCount',
              ),
              const SizedBox(height: 12),
              const _LanguageSelectorTile(),
              const SizedBox(height: 20),
              _NfcTokenSection(
                requests: _tokenRequests,
                loading: _loadingRequests,
                requesting: _requestingToken,
                error: _nfcError,
                onRefresh: _loadTokenRequests,
                onRequest: _requestToken,
                onCopy: _copyToken,
                onConsume: _consumeToken,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  strings.logout,
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askTokenName(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _TokenNameDialog(),
    );
  }

  void _confirmLogout(BuildContext context) {
    final strings = context.readStrings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.logoutQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Закрываем экран профиля; _HomeRouter сам уведёт на логин.
              Navigator.of(context).maybePop();
              context.read<AuthProvider>().logout();
            },
            child: Text(
              strings.logout,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenNameDialog extends StatefulWidget {
  const _TokenNameDialog();

  @override
  State<_TokenNameDialog> createState() => _TokenNameDialogState();
}

class _TokenNameDialogState extends State<_TokenNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.requestNfcToken),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: strings.cardName,
          hintText: strings.cardNameHint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(strings.send),
        ),
      ],
    );
  }
}

class _LanguageSelectorTile extends StatelessWidget {
  const _LanguageSelectorTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final localeProvider = context.watch<LocaleProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.language, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<AppLanguage>(
              initialValue: localeProvider.language,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: strings.languageLabel,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              items: [
                DropdownMenuItem(
                  value: AppLanguage.ru,
                  child: Text(strings.russian),
                ),
                DropdownMenuItem(
                  value: AppLanguage.en,
                  child: Text(strings.english),
                ),
              ],
              onChanged: (language) {
                if (language == null) return;
                context.read<LocaleProvider>().setLanguage(language);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcTokenSection extends StatelessWidget {
  final List<NfcTokenRequest> requests;
  final bool loading;
  final bool requesting;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onRequest;
  final ValueChanged<NfcTokenRequest> onCopy;
  final ValueChanged<NfcTokenRequest> onConsume;

  const _NfcTokenSection({
    required this.requests,
    required this.loading,
    required this.requesting,
    required this.error,
    required this.onRefresh,
    required this.onRequest,
    required this.onCopy,
    required this.onConsume,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.nfc_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.nfcToken,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.refresh,
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (error != null) ...[
            _InlineError(message: error!),
            const SizedBox(height: 12),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (requests.isEmpty)
            Text(
              strings.nfcTokenEmpty,
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            ...requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NfcTokenRequestTile(
                  request: request,
                  onCopy: onCopy,
                  onConsume: onConsume,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: requesting ? null : onRequest,
            icon: requesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_card),
            label: Text(strings.requestNfcToken),
          ),
        ],
      ),
    );
  }
}

class _NfcTokenRequestTile extends StatelessWidget {
  final NfcTokenRequest request;
  final ValueChanged<NfcTokenRequest> onCopy;
  final ValueChanged<NfcTokenRequest> onConsume;

  const _NfcTokenRequestTile({
    required this.request,
    required this.onCopy,
    required this.onConsume,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final hasToken = request.isApproved && request.ndefUri.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _RequestStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _requestSubtitle(request, strings),
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
          if (hasToken) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                request.ndefUri,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => onCopy(request),
                  icon: const Icon(Icons.copy),
                  label: Text(strings.copy, softWrap: false),
                ),
                IconButton(
                  tooltip: strings.iWroteCard,
                  onPressed: () => onConsume(request),
                  icon: const Icon(Icons.done_all),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _requestSubtitle(NfcTokenRequest request, AppStrings strings) {
    if (request.status == 'revoked') {
      return strings.nfcKeyRevoked;
    }
    if (request.isApproved) {
      return strings.approvedAt(_fmtDate(request.approvedAt));
    }
    if (request.isRejected) {
      return strings.rejectedAt(_fmtDate(request.rejectedAt));
    }
    if (request.isConsumed) {
      return strings.consumedAt(_fmtDate(request.consumedAt));
    }
    return strings.createdAt(_fmtDate(request.createdAt));
  }
}

class _RequestStatusBadge extends StatelessWidget {
  final String status;

  const _RequestStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    late final String text;
    late final Color? color;

    switch (status) {
      case 'approved':
        text = strings.approved;
        color = Colors.green[700];
        break;
      case 'rejected':
        text = strings.rejected;
        color = Colors.red[700];
        break;
      case 'consumed':
        text = strings.consumed;
        color = Colors.blueGrey[700];
        break;
      case 'revoked':
        text = strings.revoked;
        color = Colors.red[700];
        break;
      default:
        text = strings.pending;
        color = Colors.orange[800];
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(message, style: TextStyle(color: Colors.red[700]));
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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
