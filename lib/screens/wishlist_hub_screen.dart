import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../models/wishlist_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notes_provider.dart';
import '../services/wishlist_service.dart';
import '../widgets/wishlist_widgets.dart';
import 'wishlist_edit_screen.dart';
import 'wishlist_view_screen.dart';

Note teamWishlist(Map<String, dynamic> value) => Note(
      id: value['id'] as String,
      title: value['title'] as String,
      body: value['body'] as String,
      noteType: NoteType.wishlist,
      wishlistData: value['wishlistData'] as String,
      imagePath: (value['imagePath'] as String? ?? '').isEmpty
          ? null
          : value['imagePath'] as String,
    );

class WishlistHubScreen extends StatefulWidget {
  final String? initialLink;
  final WishlistService? service;
  const WishlistHubScreen({super.key, this.initialLink, this.service});
  @override
  State<WishlistHubScreen> createState() => _WishlistHubScreenState();
}

class _WishlistHubScreenState extends State<WishlistHubScreen> {
  late final _link = TextEditingController(text: widget.initialLink);
  late final _service = widget.service ?? WishlistService();
  List<dynamic> _shared = [];
  bool _busy = false, _loading = true;
  Object? _loadError;
  String? get _token => context.read<AuthProvider>().token;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.readStrings.errorMessage(error))));
    }
  }

  Future<void> _load() async {
    if (_token == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final values = await _service.json('/api/wishlists/shared', _token!);
      if (mounted) setState(() => _shared = values as List);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    if (_busy || _token == null) return;
    try {
      final token = WishlistService.linkToken(_link.text);
      if (!await wishlistConfirm(
              context, context.readStrings.wishlistImportConsent) ||
          !mounted) {
        return;
      }
      setState(() => _busy = true);
      final data = await _service
          .json('/api/public/wishlists/$token/import', _token!, method: 'POST');
      if (!mounted) return;
      final note = Note.fromJson(Map<String, dynamic>.from(data as Map));
      await context
          .read<NotesProvider>()
          .loadServerNotes(token: _token, force: true);
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => WishlistViewScreen(note: note)));
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Scaffold(
        appBar: AppBar(title: Text(s.wishlistHub)),
        body: _token == null
            ? Center(child: Text(s.wishlistSignInRequired))
            : ListView(padding: const EdgeInsets.all(16), children: [
                TextField(
                    controller: _link,
                    keyboardType: TextInputType.url,
                    decoration:
                        InputDecoration(labelText: s.wishlistImportHint)),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(s.wishlistImport)),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: Text(s.wishlistHub,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh))
                ]),
                if (_loading) const LinearProgressIndicator(),
                if (_loadError != null) Text(s.errorMessage(_loadError!)),
                for (final item in _shared)
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.group_outlined),
                          title: Text(item['title'] as String),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => WishlistTeamScreen(
                                      noteId: item['id'] as String))))),
              ]));
  }
}

class WishlistTeamScreen extends StatefulWidget {
  final String noteId;
  final bool editImmediately;
  const WishlistTeamScreen(
      {super.key, required this.noteId, this.editImmediately = false});
  @override
  State<WishlistTeamScreen> createState() => _WishlistTeamScreenState();
}

class _WishlistTeamScreenState extends State<WishlistTeamScreen> {
  final _service = WishlistService();
  Map<String, dynamic>? _team, _activity;
  Object? _error;
  bool _busy = false, _opened = false;
  String get _path => '/api/notes/${widget.noteId}/wishlist';
  String get _token => context.read<AuthProvider>().token!;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _message(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.readStrings.errorMessage(error))));
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final team = Map<String, dynamic>.from(
          await _service.json('$_path/team', _token) as Map);
      final activity = team['isOwner'] == true
          ? Map<String, dynamic>.from(
              await _service.json('$_path/activity', _token) as Map)
          : null;
      if (!mounted) return;
      setState(() {
        _team = team;
        _activity = activity;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _team != null && widget.editImmediately && !_opened) {
      _opened = true;
      await _edit();
    }
  }

  Future<void> _edit() async {
    final initial = _team!;
    await Navigator.push<Note>(
        context,
        MaterialPageRoute(
            builder: (_) => WishlistEditScreen(
                  initialNote: teamWishlist(initial),
                  collaborative: initial['isOwner'] != true,
                  onSave: (draft) async {
                    if (initial['isOwner'] == true) {
                      return context.read<NotesProvider>().saveWishlist(draft,
                          token: _token,
                          userId: context.read<AuthProvider>().userId,
                          wishlistRevision: initial['revision'] as int);
                    }
                    final uploaded = await context
                        .read<NotesProvider>()
                        .prepareWishlistUploads(draft, _token);
                    final saved = Map<String, dynamic>.from(await _service
                        .json('$_path/team', _token, method: 'PATCH', body: {
                      'revision': initial['revision'],
                      'title': uploaded.title,
                      'body': uploaded.body,
                      'wishlistData': uploaded.wishlistData,
                    }) as Map);
                    if (mounted && saved['isOwner'] == true) {
                      await context
                          .read<NotesProvider>()
                          .loadServerNotes(token: _token, force: true);
                    }
                    return teamWishlist(saved);
                  },
                )));
    if (mounted) await _load();
  }

  Future<void> _invite() async {
    var input = "";
    final email = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(context.readStrings.wishlistInvite),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.readStrings.wishlistEditorsHint),
                  TextField(
                      onChanged: (value) => input = value,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.readStrings.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, input.trim()),
                      child: Text(context.readStrings.wishlistInvite))
                ]));
    if (email == null || email.isEmpty || !mounted) return;
    await _change('team', 'POST', {'email': email});
  }

  Future<void> _change(
      String resource, String method, Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.json('$_path/$resource', _token,
          method: method, body: body);
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Scaffold(
        appBar: AppBar(
            title: Text(_team?['title'] as String? ?? s.wishlistTeam),
            actions: [
              IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh))
            ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(s.errorMessage(_error!)),
          if (_team != null) ...[
            FilledButton.icon(
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.edit)),
            if (_team!['isOwner'] == true) ...[
              const SizedBox(height: 16),
              Text(s.wishlistEditorsHint),
              TextButton.icon(
                  onPressed: _busy ? null : _invite,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(s.wishlistInvite)),
              for (final person in _team!['editors'] as List? ?? [])
                ListTile(
                    title: Text(person['email'] as String),
                    trailing: IconButton(
                        tooltip: s.wishlistRevokeEditor,
                        onPressed: _busy
                            ? null
                            : () async {
                                if (await wishlistConfirm(
                                        context, s.wishlistRevokeEditor) &&
                                    mounted) {
                                  await _change('team', 'DELETE',
                                      {'userId': person['id']});
                                }
                              },
                        icon: const Icon(Icons.person_remove_outlined))),
              const Divider(),
              Text(s.wishlistActivity,
                  style: Theme.of(context).textTheme.titleLarge),
              for (final item in _activity?['items'] as List? ?? [])
                ListTile(
                    title: Text(item['title'] as String),
                    subtitle: Text(item['status'] == 'purchased'
                        ? s.wishlistPurchased
                        : item['status'] == 'reserved'
                            ? s.wishlistReserved
                            : s.wishlistAvailable),
                    trailing: (item['status'] as String? ?? '').isEmpty
                        ? null
                        : IconButton(
                            tooltip: s.wishlistReset,
                            icon: const Icon(Icons.restart_alt),
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await wishlistConfirm(
                                            context, s.wishlistResetConfirm) &&
                                        mounted) {
                                      await _change('activity', 'DELETE',
                                          {'item': item['id']});
                                    }
                                  })),
              for (final comment in _activity?['comments'] as List? ?? [])
                Card(
                    child: ListTile(
                        title: Text(comment['name'] as String),
                        subtitle: Text(comment['body'] as String),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: s.delete,
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await wishlistConfirm(
                                            context, s.delete) &&
                                        mounted) {
                                      await _change('activity', 'DELETE',
                                          {'comment': comment['id']});
                                    }
                                  }))),
            ],
          ],
        ]));
  }
}
