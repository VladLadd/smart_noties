import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../models/feedback_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/feedback_service.dart';

mixin _FeedbackSessionGuard<T extends StatefulWidget> on State<T> {
  String? _session;
  bool get feedbackAdmin => false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (feedbackAdmin) return;
    final auth = context.watch<AuthProvider>();
    final current =
        auth.token == null ? 'guest' : 'user:${auth.userId ?? auth.token}';
    if (_session != null && _session != current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _session = current;
  }
}

const _categories = ['feedback', 'bug', 'crash'];
const _statuses = ['new', 'in_progress', 'resolved'];
String _date(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final l = MaterialLocalizations.of(context);
  return '${l.formatShortDate(local)} ${l.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

Future<bool> _discard(BuildContext context, AppStrings s) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            AlertDialog(content: Text(s.feedbackDiscard), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.confirm))
            ])) ??
    false;

class FeedbackEntryTile extends StatefulWidget {
  const FeedbackEntryTile({super.key});
  @override
  State<FeedbackEntryTile> createState() => _FeedbackEntryTileState();
}

class _FeedbackEntryTileState extends State<FeedbackEntryTile> {
  int _unread = 0;
  String? _identity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthProvider>().token;
    final key = token ?? 'guest';
    if (_identity != key) {
      _identity = key;
      _unread = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final token = context.read<AuthProvider>().token;
    try {
      final page = await FeedbackService.shared.list(token: token);
      if (mounted && token == context.read<AuthProvider>().token) {
        setState(() => _unread = page.unreadCount);
      }
    } catch (_) {/* Ссылка доступна и при временной ошибке сети. */}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: Text(s.feedbackTitle),
            subtitle: Text(s.feedbackHint),
            trailing: _unread == 0
                ? const Icon(Icons.chevron_right)
                : Badge(
                    label: Text('$_unread'),
                    child: const Icon(Icons.mark_chat_unread_outlined)),
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FeedbackInboxScreen()));
              await _refresh();
            }));
  }
}

class FeedbackInboxScreen extends StatefulWidget {
  final bool admin;
  final String? token;
  final FeedbackService? service;
  const FeedbackInboxScreen(
      {super.key, this.admin = false, this.token, this.service});
  @override
  State<FeedbackInboxScreen> createState() => _FeedbackInboxScreenState();
}

class _FeedbackInboxScreenState extends State<FeedbackInboxScreen>
    with _FeedbackSessionGuard {
  @override
  bool get feedbackAdmin => widget.admin;
  late final _service = widget.service ?? FeedbackService.shared;
  final _search = TextEditingController();
  FeedbackPage _page = const FeedbackPage();
  String _status = '', _category = '';
  int _offset = 0, _generation = 0;
  bool _loading = true;
  Object? _error;
  String? get _token =>
      widget.admin ? widget.token : context.read<AuthProvider>().token;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.list(
          token: _token,
          admin: widget.admin,
          query: _search.text.trim(),
          status: _status,
          category: _category,
          offset: _offset);
      if (mounted && generation == _generation) setState(() => _page = page);
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String id) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FeedbackThreadScreen(
                id: id,
                admin: widget.admin,
                token: widget.token,
                service: _service)));
    if (mounted) await _load();
  }

  Future<void> _new() async {
    final value = await Navigator.push<FeedbackThread>(
        context,
        MaterialPageRoute(
            builder: (_) => FeedbackComposeScreen(service: _service)));
    if (value == null || !mounted) return;
    _offset = 0;
    await _open(value.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.admin ? const AppStrings(AppLanguage.ru) : context.strings;
    return Scaffold(
        appBar: AppBar(title: Text(s.feedbackTitle), actions: [
          IconButton(
              tooltip: s.feedbackRefresh,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: widget.admin
            ? null
            : FloatingActionButton.extended(
                onPressed: _new,
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.feedbackNew)),
        body: Column(children: [
          if (widget.admin)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                      controller: _search,
                      decoration: InputDecoration(
                          labelText: s.feedbackSearch,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      _offset = 0;
                                      _load();
                                    },
                              icon: const Icon(Icons.search))),
                      onSubmitted: (_) {
                        _offset = 0;
                        _load();
                      }),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            items: [
                              DropdownMenuItem(
                                  value: '',
                                  child: Text(s.feedbackAllStatuses)),
                              for (final status in _statuses)
                                DropdownMenuItem(
                                    value: status,
                                    child: Text(s.feedbackStatus(status)))
                            ],
                            onChanged: _loading
                                ? null
                                : (value) {
                                    setState(() {
                                      _status = value ?? '';
                                      _offset = 0;
                                    });
                                    _load();
                                  })),
                    SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            items: [
                              DropdownMenuItem(
                                  value: '',
                                  child: Text(s.feedbackAllCategories)),
                              for (final category in _categories)
                                DropdownMenuItem(
                                    value: category,
                                    child: Text(s.feedbackCategory(category)))
                            ],
                            onChanged: _loading
                                ? null
                                : (value) {
                                    setState(() {
                                      _category = value ?? '';
                                      _offset = 0;
                                    });
                                    _load();
                                  })),
                  ]),
                ])),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.errorMessage(_error!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (!_loading && _error == null)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${s.feedbackUnread}: ${_page.unreadCount}'))),
          Expanded(
              child: !_loading && _page.items.isEmpty && _error == null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(widget.admin
                              ? s.feedbackAdminEmpty
                              : s.feedbackEmpty)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: _page.items.length,
                      itemBuilder: (context, index) {
                        final thread = _page.items[index];
                        final author = thread.author;
                        final name = author == null
                            ? ''
                            : (author['email'] as String? ?? '').isNotEmpty
                                ? author['email'] as String
                                : thread.contactEmail.isNotEmpty
                                    ? thread.contactEmail
                                    : s.feedbackGuest;
                        return Card(
                            child: ListTile(
                                leading: Icon(
                                    thread.unread
                                        ? Icons.mark_chat_unread_outlined
                                        : Icons.chat_bubble_outline,
                                    color: thread.unread
                                        ? Theme.of(context).colorScheme.primary
                                        : null),
                                title: Text(thread.subject,
                                    style: TextStyle(
                                        fontWeight: thread.unread
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                                subtitle: Text(
                                    '${s.feedbackCategory(thread.category)} · ${s.feedbackStatus(thread.status)}\n${widget.admin ? '$name · ' : ''}${_date(context, thread.updatedAt)}\n${thread.preview}',
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _open(thread.id)));
                      })),
          if (_page.total > 25 || _offset > 0)
            SafeArea(
                top: false,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(
                      onPressed: _loading || _offset == 0
                          ? null
                          : () {
                              _offset = (_offset - 25).clamp(0, 100000);
                              _load();
                            },
                      child: Text(s.feedbackPrevious)),
                  Text(
                      '${_offset + 1}–${(_offset + _page.items.length).clamp(0, _page.total)} / ${_page.total}'),
                  TextButton(
                      onPressed: _loading || _offset + 25 >= _page.total
                          ? null
                          : () {
                              _offset += 25;
                              _load();
                            },
                      child: Text(s.feedbackNext))
                ])),
        ]));
  }
}

class FeedbackComposeScreen extends StatefulWidget {
  final FeedbackService? service;
  const FeedbackComposeScreen({super.key, this.service});
  @override
  State<FeedbackComposeScreen> createState() => _FeedbackComposeScreenState();
}

class _FeedbackComposeScreenState extends State<FeedbackComposeScreen>
    with _FeedbackSessionGuard {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController(),
      _body = TextEditingController(),
      _email = TextEditingController();
  String _category = 'feedback', _requestId = FeedbackService.newRequestId();
  String _draftSignature = '';
  bool _busy = false, _dirty = false, _allowPop = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    for (final controller in [_subject, _body, _email]) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    final signature =
        jsonEncode([_category, _subject.text, _body.text, _email.text]);
    if (signature == _draftSignature) return;
    _draftSignature = signature;
    _dirty = _category != 'feedback' ||
        _subject.text.isNotEmpty ||
        _body.text.isNotEmpty ||
        _email.text.isNotEmpty;
    _requestId = FeedbackService.newRequestId();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (!_dirty || await _discard(context, context.readStrings)) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await (widget.service ?? FeedbackService.shared).create(
          token: context.read<AuthProvider>().token,
          requestId: _requestId,
          category: _category,
          subject: _subject.text.trim(),
          body: _body.text.trim(),
          contactEmail: _email.text.trim(),
          locale: context.read<LocaleProvider>().language.code);
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, value);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final guest = context.watch<AuthProvider>().token == null;
    return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (popped, _) {
          if (!popped) _leave();
        },
        child: Scaffold(
            appBar: AppBar(
                leading: IconButton(
                    onPressed: _busy ? null : _leave,
                    icon: const Icon(Icons.arrow_back)),
                title: Text(s.feedbackNew)),
            body: Form(
                key: _form,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                              initialValue: _category,
                              items: [
                                for (final category in _categories)
                                  DropdownMenuItem(
                                      value: category,
                                      child: Text(s.feedbackCategory(category)))
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      setState(() => _category = value!);
                                      _changed();
                                    }),
                          const SizedBox(height: 16),
                          TextFormField(
                              key: const ValueKey('feedback-subject'),
                              controller: _subject,
                              enabled: !_busy,
                              maxLength: 160,
                              decoration:
                                  InputDecoration(labelText: s.feedbackSubject),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? s.feedbackRequired
                                      : null),
                          const SizedBox(height: 12),
                          TextFormField(
                              key: const ValueKey('feedback-body'),
                              controller: _body,
                              enabled: !_busy,
                              maxLength: 6000,
                              minLines: 6,
                              maxLines: 14,
                              decoration: InputDecoration(
                                  labelText: s.feedbackBody,
                                  hintText: s.feedbackBodyHint,
                                  alignLabelWithHint: true),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? s.feedbackRequired
                                      : null),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              maxLength: 254,
                              keyboardType: TextInputType.emailAddress,
                              decoration:
                                  InputDecoration(labelText: s.feedbackContact),
                              validator: (value) => value != null &&
                                      value.trim().isNotEmpty &&
                                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(value.trim())
                                  ? s.feedbackInvalidEmail
                                  : null),
                          Text(s.feedbackContactHint,
                              style: Theme.of(context).textTheme.bodySmall),
                          if (guest)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(s.feedbackGuestHint,
                                    style:
                                        Theme.of(context).textTheme.bodySmall)),
                          const SizedBox(height: 16),
                          Text(
                              '${s.feedbackPlatform}: ${FeedbackService.platform}',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(s.errorMessage(_error!),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                              onPressed: _busy ? null : _send,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send_outlined),
                              label: Text(s.feedbackSubmit)),
                        ])))));
  }
}

class FeedbackThreadScreen extends StatefulWidget {
  final String id;
  final bool admin;
  final String? token;
  final FeedbackService? service;
  const FeedbackThreadScreen(
      {super.key,
      required this.id,
      this.admin = false,
      this.token,
      this.service});
  @override
  State<FeedbackThreadScreen> createState() => _FeedbackThreadScreenState();
}

class _FeedbackThreadScreenState extends State<FeedbackThreadScreen>
    with _FeedbackSessionGuard {
  @override
  bool get feedbackAdmin => widget.admin;
  late final _service = widget.service ?? FeedbackService.shared;
  final _reply = TextEditingController();
  String _requestId = FeedbackService.newRequestId(), _lastReply = '';
  FeedbackThread? _thread;
  bool _busy = true, _allowPop = false;
  Object? _error;
  String? get _token =>
      widget.admin ? widget.token : context.read<AuthProvider>().token;
  AppStrings get _s =>
      widget.admin ? const AppStrings(AppLanguage.ru) : context.readStrings;
  @override
  void initState() {
    super.initState();
    _reply.addListener(() {
      if (_lastReply == _reply.text) return;
      _lastReply = _reply.text;
      _requestId = FeedbackService.newRequestId();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final thread =
          await _service.read(widget.id, token: _token, admin: widget.admin);
      if (mounted) setState(() => _thread = thread);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _reply.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await _service.reply(widget.id,
          token: _token,
          admin: widget.admin,
          requestId: _requestId,
          body: _reply.text.trim());
      if (mounted) {
        setState(() => _thread = value);
        _reply.clear();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _status(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final value = await _service.setStatus(widget.id, status, token: _token!);
      if (mounted) setState(() => _thread = value);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (_reply.text.isEmpty || await _discard(context, _s)) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.admin ? const AppStrings(AppLanguage.ru) : context.strings;
    final thread = _thread;
    return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (popped, _) {
          if (!popped) _leave();
        },
        child: Scaffold(
            appBar: AppBar(
                leading: IconButton(
                    onPressed: _busy ? null : _leave,
                    icon: const Icon(Icons.arrow_back)),
                title: Text(thread?.subject ?? s.feedbackTitle),
                actions: [
                  IconButton(
                      tooltip: s.feedbackRefresh,
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.refresh))
                ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              if (_busy) const LinearProgressIndicator(),
              if (thread != null) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text(s.feedbackCategory(thread.category))),
                  Chip(label: Text(s.feedbackStatus(thread.status))),
                  Chip(label: Text('${s.feedbackPlatform}: ${thread.platform}'))
                ]),
                if (widget.admin) ...[
                  if (thread.author != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SelectableText([
                          if (thread.author!['id'] == null) s.feedbackGuest,
                          thread.author!['name'] ?? '',
                          thread.author!['email'] ?? '',
                          thread.author!['phone'] ?? '',
                          thread.contactEmail
                        ]
                            .where((value) => value.toString().isNotEmpty)
                            .join('\n'))),
                  DropdownButtonFormField<String>(
                      key: ValueKey(thread.status),
                      initialValue: thread.status,
                      items: [
                        for (final status in _statuses)
                          DropdownMenuItem(
                              value: status,
                              child: Text(s.feedbackStatus(status)))
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) _status(value);
                            }),
                ],
                const SizedBox(height: 16),
                for (final message in thread.messages)
                  Align(
                      alignment: message.sender == 'admin'
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Card(
                              color: message.sender == 'admin'
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            message.sender == 'admin'
                                                ? s.feedbackDeveloper
                                                : widget.admin
                                                    ? s.feedbackUser
                                                    : s.feedbackYou,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        SelectableText(message.body),
                                        const SizedBox(height: 8),
                                        Text(_date(context, message.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall)
                                      ]))))),
              ],
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.errorMessage(_error!),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              if (thread != null) ...[
                const SizedBox(height: 16),
                TextField(
                    key: const ValueKey('feedback-reply'),
                    controller: _reply,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 10,
                    maxLength: 6000,
                    decoration: InputDecoration(
                        labelText: s.feedbackReply,
                        hintText: s.feedbackReplyHint,
                        alignLabelWithHint: true)),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(s.feedbackReply)),
              ],
            ])));
  }
}
