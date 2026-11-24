import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notes_provider.dart';
import '../services/wishlist_service.dart';
import '../widgets/wishlist_widgets.dart';
import 'wishlist_edit_screen.dart';
import 'wishlist_hub_screen.dart';
import 'login_screen.dart';

class WishlistViewScreen extends StatefulWidget {
  final Note note;
  final WishlistService? service;
  const WishlistViewScreen({super.key, required this.note, this.service});
  @override
  State<WishlistViewScreen> createState() => _WishlistViewScreenState();
}

class _WishlistViewScreenState extends State<WishlistViewScreen> {
  late Note _note = widget.note;
  WishlistShareState _share = const WishlistShareState(active: false);
  bool _busy = false;
  late final _service = widget.service ?? WishlistService();
  bool get _local =>
      _note.isPending ||
      _note.id.startsWith('guest_') ||
      _note.id.startsWith('local_');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadShare());
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.readStrings.errorMessage(error))));
    }
  }

  Future<void> _loadShare() async {
    if (!mounted || _local) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final state = await _service.request(_note.id, token);
      if (mounted) setState(() => _share = state);
    } catch (_) {/* Сохранённый список остаётся доступен при ошибке сети. */}
  }

  Future<void> _edit() async {
    if (!_local &&
        !_note.hasProtection &&
        !_note.isArchived &&
        !_note.isHidden) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  WishlistTeamScreen(noteId: _note.id, editImmediately: true)));
      if (!mounted) return;
      try {
        final data = await _service.json('/api/notes/${_note.id}/wishlist/team',
            context.read<AuthProvider>().token!);
        if (mounted) {
          setState(() =>
              _note = teamWishlist(Map<String, dynamic>.from(data as Map)));
        }
      } catch (_) {
        if (mounted) {
          final current = context
              .read<NotesProvider>()
              .notes
              .where((n) => n.id == _note.id)
              .firstOrNull;
          if (current == null ||
              current.hasProtection ||
              current.isHidden ||
              current.isArchived) {
            Navigator.pop(context);
            return;
          }
        }
      }
      await _loadShare();
      return;
    }
    final saved = await Navigator.push<Note>(
        context,
        MaterialPageRoute(
            builder: (_) => WishlistEditScreen(initialNote: _note)));
    if (saved != null && mounted) {
      setState(() => _note = saved);
      await _loadShare();
    }
  }

  Future<void> _publish() async {
    if (_busy) return;
    final strings = context.readStrings;
    if (_note.hasProtection || _note.isHidden || _note.isArchived) {
      _error(strings.wishlistPrivateOnly);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.token == null || auth.userId == null || auth.isGuest) {
      if (!await wishlistConfirm(context, strings.wishlistNeedsAccount,
              action: strings.guestSignIn) ||
          !mounted) {
        return;
      }
      await context.read<NotesProvider>().offerGuestWishlist(_note);
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const WishlistSignInScreen()));
      return;
    }
    if (_local &&
        (!await wishlistConfirm(context, strings.wishlistUploadConsent,
                action: strings.wishlistUpload) ||
            !mounted)) {
      return;
    }
    if (!_share.active &&
        (!await wishlistConfirm(context, strings.wishlistConsent,
                action: strings.publishWishlist) ||
            !mounted)) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (_local) {
        final saved = await context
            .read<NotesProvider>()
            .uploadWishlist(_note, token: auth.token!, userId: auth.userId!);
        if (!mounted) return;
        setState(() => _note = saved);
      }
      final state =
          await _service.request(_note.id, auth.token!, method: 'POST');
      if (!mounted) return;
      setState(() => _share = state);
      await _shareDialog();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareDialog() async {
    if (_share.url == null) return;
    var managing = false;
    await showDialog(
        context: context,
        builder: (dialog) => StatefulBuilder(builder: (ctx, update) {
              final s = context.readStrings;
              return AlertDialog(
                  title: Text(s.shareWishlist),
                  content: SizedBox(
                      width: 480,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.wishlistConsent),
                            const SizedBox(height: 16),
                            SelectableText(_share.url ?? ''),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              OutlinedButton.icon(
                                  icon: const Icon(Icons.copy),
                                  label: Text(s.copy),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: _share.url!));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(s.linkCopied)));
                                    }
                                  }),
                              Builder(
                                  builder: (button) => FilledButton.icon(
                                      icon: const Icon(Icons.ios_share),
                                      label: Text(s.send),
                                      onPressed: () async {
                                        final box = button.findRenderObject()
                                            as RenderBox?;
                                        try {
                                          await Share.share(_share.url!,
                                              subject: _note.title,
                                              sharePositionOrigin: box == null
                                                  ? null
                                                  : box.localToGlobal(
                                                          Offset.zero) &
                                                      box.size);
                                        } catch (error) {
                                          _error(error);
                                        }
                                      })),
                            ]),
                            TextButton(
                                onPressed: managing
                                    ? null
                                    : () async {
                                        if (!await wishlistConfirm(context,
                                                s.rotateWishlistConfirm) ||
                                            !mounted) {
                                          return;
                                        }
                                        if (managing) return;
                                        update(() => managing = true);
                                        try {
                                          final state = await _service.request(
                                              _note.id,
                                              context
                                                  .read<AuthProvider>()
                                                  .token!,
                                              method: 'POST',
                                              rotate: true);
                                          if (mounted && ctx.mounted) {
                                            setState(() => _share = state);
                                            update(() {});
                                          }
                                        } catch (error) {
                                          _error(error);
                                        } finally {
                                          if (ctx.mounted) {
                                            update(() => managing = false);
                                          }
                                        }
                                      },
                                child: Text(s.rotateWishlistLink)),
                            TextButton(
                                onPressed: managing
                                    ? null
                                    : () async {
                                        if (!await wishlistConfirm(context,
                                                s.wishlistRevocationWarning) ||
                                            !mounted) {
                                          return;
                                        }
                                        if (managing) return;
                                        update(() => managing = true);
                                        try {
                                          await _service.request(
                                              _note.id,
                                              context
                                                  .read<AuthProvider>()
                                                  .token!,
                                              method: 'DELETE');
                                          if (mounted && ctx.mounted) {
                                            setState(() => _share =
                                                const WishlistShareState(
                                                    active: false));
                                            Navigator.pop(ctx);
                                          }
                                        } catch (error) {
                                          _error(error);
                                        } finally {
                                          if (ctx.mounted) {
                                            update(() => managing = false);
                                          }
                                        }
                                      },
                                child: Text(s.disableWishlistLink)),
                          ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(s.close))
                  ]);
            }));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    List items;
    try {
      items = _note.wishlist.items;
    } catch (_) {
      return Scaffold(
          appBar: AppBar(title: Text(s.wishlist)),
          body: Center(child: Text(s.wishlistUnsupported)));
    }
    final token = context.watch<AuthProvider>().token;
    return Scaffold(
        appBar: AppBar(title: Text(s.wishlist), actions: [
          if (!_local &&
              !_note.hasProtection &&
              !_note.isHidden &&
              !_note.isArchived)
            IconButton(
                tooltip: s.wishlistTeam,
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                WishlistTeamScreen(noteId: _note.id))),
                icon: const Icon(Icons.group_outlined)),
          IconButton(
              tooltip: s.edit,
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_note.imagePath != null)
            wishlistImage(_note.imagePath!,
                token: token, password: _note.protectionPassword, height: 240),
          const SizedBox(height: 16),
          Text(_note.title, style: Theme.of(context).textTheme.headlineLarge),
          if (_note.body.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_note.body)),
          if (_share.active)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Icon(Icons.link),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.wishlistSharingActive))
                ])),
          if (items.isEmpty)
            Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.wishlistEmpty)),
          for (final item in items)
            GiftCard(item: item, note: _note, token: token),
        ]),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                    onPressed: _busy ? null : _publish,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.ios_share),
                    label: Text(s.shareWishlist)))));
  }
}

// После входа выбранный локальный список остаётся в общем списке для явной загрузки.
class WishlistSignInScreen extends StatelessWidget {
  const WishlistSignInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthProvider>().status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    return const LoginScreen();
  }
}
