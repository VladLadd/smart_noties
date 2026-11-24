import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../models/wishlist_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notes_provider.dart';
import '../services/image_normalizer.dart';
import '../services/note_client_crypto.dart';
import '../services/wishlist_service.dart';
import '../widgets/wishlist_widgets.dart';

class WishlistEditScreen extends StatefulWidget {
  final Note? initialNote;
  final Future<Note> Function(Note)? onSave;
  final bool collaborative;
  const WishlistEditScreen(
      {super.key, this.initialNote, this.onSave, this.collaborative = false});
  @override
  State<WishlistEditScreen> createState() => _WishlistEditScreenState();
}

class _WishlistEditScreenState extends State<WishlistEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initialNote?.title);
  late final _body = TextEditingController(text: widget.initialNote?.body);
  late Note _base;
  List<WishlistItem> _items = [];
  String? _cover;
  bool _busy = false,
      _picking = false,
      _allowPop = false,
      _dirty = false,
      _unsupported = false;
  final List<Directory> _temporary = [];
  @override
  void initState() {
    super.initState();
    _base = widget.initialNote ??
        Note(
            id: 'local_${DateTime.now().microsecondsSinceEpoch}',
            noteType: NoteType.wishlist,
            title: '',
            body: '',
            wishlistData: const WishlistData().encode());
    _cover = _base.imagePath;
    try {
      _items = List.of(_base.wishlist.items);
    } catch (_) {
      _unsupported = true;
    }
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  void _changed() {
    _dirty = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    for (final d in _temporary) {
      d.delete(recursive: true).catchError((_) => d);
    }
    super.dispose();
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.readStrings.errorMessage(error))));
    }
  }

  Future<String?> _pickImage() async {
    if (_picking) return null;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1800,
          maxHeight: 1800);
      if (picked == null || !mounted) return null;
      final converted = await const ImageNormalizer()
          .normalize(picked, token: context.read<AuthProvider>().token);
      if (converted == null) return picked.path;
      if (kIsWeb) {
        return XFile.fromData(converted,
                mimeType: 'image/jpeg', name: 'gift.jpg')
            .path;
      }
      final directory =
          await Directory.systemTemp.createTemp('wishlist-image-');
      _temporary.add(directory);
      final file = File('${directory.path}/gift.jpg');
      await file.writeAsBytes(converted);
      return file.path;
    } catch (error) {
      _error(error);
      return null;
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _gift([int? index]) async {
    final strings = context.readStrings;
    if (index == null && _items.length >= 100) {
      _error(strings.wishlistLimit);
      return;
    }
    final value = await showDialog<WishlistItem>(
        context: context,
        builder: (_) => _GiftDialog(
            item: index == null ? null : _items[index], pickImage: _pickImage));
    if (value != null && mounted) {
      setState(() {
        if (index == null) {
          _items.add(value);
        } else {
          _items[index] = value;
        }
        _dirty = true;
      });
    }
  }

  Future<bool> _mayRevoke() async {
    final token = context.read<AuthProvider>().token;
    if (token == null ||
        _base.id.startsWith('local_') ||
        _base.id.startsWith('guest_')) {
      return true;
    }
    try {
      final state = await WishlistService().request(_base.id, token);
      if (!mounted) return false;
      return !state.active ||
          await wishlistConfirm(
              context, context.readStrings.wishlistRevocationWarning);
    } catch (error) {
      _error(error);
      return false;
    }
  }

  Future<void> _privacy(String action) async {
    if (_busy) return;
    if (action == 'password') {
      var value = '';
      final key = GlobalKey<FormState>();
      final password = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(context.readStrings.protectWishlist),
                  content: Form(
                      key: key,
                      child: TextFormField(
                          obscureText: true,
                          onChanged: (v) => value = v,
                          decoration: InputDecoration(
                              helperText:
                                  context.readStrings.wishlistPasswordHint,
                              helperMaxLines: 3),
                          validator: (v) =>
                              v != null && v.isNotEmpty && v.length < 6
                                  ? context.readStrings.wishlistPasswordHint
                                  : null)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(context.readStrings.cancel)),
                    FilledButton(
                        onPressed: () {
                          if (key.currentState!.validate()) {
                            Navigator.pop(ctx, value);
                          }
                        },
                        child: Text(context.readStrings.save))
                  ]));
      if (password == null || !mounted) return;
      if (password.isNotEmpty && !await _mayRevoke()) return;
      if (!mounted) return;
      setState(() => _base = _base.copyWith(
          isProtected: password.isNotEmpty,
          protectionPassword: password,
          clearProtectionPassword: password.isEmpty));
      _dirty = true;
    } else {
      final notes = context.read<NotesProvider>();
      final enable = !_base.isHidden;
      if (enable && notes.activeHiddenKeyId == null) {
        _error(context.readStrings.wishlistSelectNfc);
        return;
      }
      if (enable && !await _mayRevoke()) return;
      if (mounted) {
        setState(() => _base = _base.copyWith(
            isHidden: enable,
            hiddenKeyId: enable ? notes.activeHiddenKeyId : null,
            clearHiddenKeyId: !enable));
      }
      _dirty = true;
    }
  }

  Future<void> _save() async {
    if (_busy || _picking || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthProvider>();
      final draft = _base.copyWith(
          title: _title.text.trim(),
          body: _body.text.trim(),
          wishlistData: WishlistData(items: _items).encode(),
          imagePath: _cover,
          clearImagePath: _cover == null,
          createdAt: _base.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now());
      var saved = widget.onSave != null
          ? await widget.onSave!(draft)
          : await context
              .read<NotesProvider>()
              .saveWishlist(draft, token: auth.token, userId: auth.userId);
      if (saved.hasProtection && draft.protectionPassword != null) {
        saved = (await decryptNoteFromClient(saved, draft.protectionPassword!))
            .copyWith(protectionPassword: draft.protectionPassword);
      }
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, saved);
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (!_dirty ||
        await wishlistConfirm(context, context.readStrings.wishlistDiscard)) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    if (_base.hasProtection && _base.protectionPassword == null) {
      return Scaffold(
          appBar: AppBar(title: Text(strings.wishlist)),
          body: Center(child: Text(strings.enterPasswordToView)));
    }
    if (_unsupported) {
      return Scaffold(
          appBar: AppBar(title: Text(strings.wishlist)),
          body: Center(child: Text(strings.wishlistUnsupported)));
    }
    return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (popped, _) {
          if (!popped) _close();
        },
        child: Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  onPressed: _close, icon: const Icon(Icons.arrow_back)),
              title: Text(strings.wishlist),
              actions: [
                if (!widget.collaborative)
                  PopupMenuButton<String>(
                      onSelected: _privacy,
                      itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'password',
                                child: Text(strings.protectWishlist)),
                            PopupMenuItem(
                                value: 'hidden',
                                child: Text(strings.wishlistHidden)),
                          ])
              ]),
          body: Form(
              key: _form,
              child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  header: Column(children: [
                    if (_picking) const LinearProgressIndicator(),
                    if (_cover != null)
                      Stack(children: [
                        wishlistImage(
                            widget.collaborative &&
                                    _cover!.startsWith('/api/image/')
                                ? '/api/notes/${_base.id}/wishlist/team-image/${Uri.parse(_cover!).pathSegments.last}'
                                : _cover!,
                            token: context.read<AuthProvider>().token,
                            password: _base.protectionPassword),
                        if (!widget.collaborative)
                          Positioned(
                              right: 8,
                              top: 8,
                              child: IconButton(
                                  onPressed: () => setState(() {
                                        _cover = null;
                                        _dirty = true;
                                      }),
                                  icon: const Icon(Icons.close)))
                      ]),
                    if (!widget.collaborative)
                      TextButton.icon(
                          onPressed: _picking
                              ? null
                              : () async {
                                  final p = await _pickImage();
                                  if (p != null && mounted) {
                                    setState(() {
                                      _cover = p;
                                      _dirty = true;
                                    });
                                  }
                                },
                          icon: const Icon(Icons.image_outlined),
                          label: Text(strings.wishlistCover)),
                    TextFormField(
                        key: const ValueKey('wishlist-title'),
                        controller: _title,
                        maxLength: 200,
                        decoration:
                            InputDecoration(labelText: strings.wishlistTitle),
                        validator: (v) {
                          final auth = context.read<AuthProvider>();
                          final local = auth.isGuest ||
                              auth.token == null ||
                              _base.id.startsWith('guest_') ||
                              _base.isPending;
                          return !local && (v == null || v.trim().isEmpty)
                              ? strings.wishlistTitle
                              : null;
                        }),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _body,
                        maxLength: 4000,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                            labelText: strings.wishlistDescription)),
                    if (_items.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(strings.wishlistEmpty)),
                  ]),
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorderItem: (old, next) {
                    setState(() {
                      final value = _items.removeAt(old);
                      _items.insert(next, value);
                      _dirty = true;
                    });
                  },
                  itemBuilder: (ctx, index) => GiftCard(
                      mediaNoteId: widget.collaborative ? _base.id : null,
                      key: ValueKey(_items[index].id),
                      item: _items[index],
                      note: _base,
                      token: context.read<AuthProvider>().token,
                      actions: Wrap(children: [
                        ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_handle))),
                        IconButton(
                            tooltip: strings.edit,
                            onPressed: () => _gift(index),
                            icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                            tooltip: strings.delete,
                            onPressed: () => setState(() {
                                  _items.removeAt(index);
                                  _dirty = true;
                                }),
                            icon: const Icon(Icons.delete_outline)),
                      ])))),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                            onPressed: _busy ? null : () => _gift(),
                            icon: const Icon(Icons.add),
                            label: Text(strings.addGift)),
                        FilledButton(
                            onPressed: _busy || _picking ? null : _save,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(strings.save)),
                      ]))),
        ));
  }
}

class _GiftDialog extends StatefulWidget {
  final WishlistItem? item;
  final Future<String?> Function() pickImage;
  const _GiftDialog({this.item, required this.pickImage});
  @override
  State<_GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<_GiftDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item?.title);
  late final _description =
      TextEditingController(text: widget.item?.description);
  late final _url = TextEditingController(text: widget.item?.productUrl);
  late final _price = TextEditingController(
      text: widget.item?.priceMinor == null
          ? ''
          : (widget.item!.priceMinor! / 100).toStringAsFixed(2));
  late String _currency = widget.item?.currency ?? 'RUB';
  late String _image = widget.item?.imagePath ?? '';
  bool _picking = false;
  int? _minor() {
    final v = _price.text.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(v)) return -1;
    final p = v.split('.');
    return int.parse(p[0]) * 100 +
        int.parse((p.length == 1 ? '' : p[1]).padRight(2, '0'));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(s.addGift),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          key: const ValueKey('gift-title'),
                          controller: _title,
                          maxLength: 200,
                          decoration: InputDecoration(labelText: s.giftName),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? s.giftName
                              : null),
                      TextFormField(
                          controller: _description,
                          maxLength: 2000,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              InputDecoration(labelText: s.giftDescription)),
                      TextFormField(
                          key: const ValueKey('gift-url'),
                          controller: _url,
                          maxLength: 2048,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(labelText: s.giftURL),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final u = Uri.tryParse(v.trim());
                            return u == null ||
                                    !['http', 'https'].contains(u.scheme) ||
                                    u.host.isEmpty ||
                                    u.userInfo.isNotEmpty
                                ? s.wishlistInvalidURL
                                : null;
                          }),
                      if (context.read<AuthProvider>().token != null)
                        TextButton.icon(
                            icon: const Icon(Icons.auto_fix_high),
                            label: Text(s.wishlistAutofill),
                            onPressed: _picking
                                ? null
                                : () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    setState(() => _picking = true);
                                    try {
                                      final data = await WishlistService().json(
                                          '/api/wishlists/product',
                                          context.read<AuthProvider>().token!,
                                          method: 'POST',
                                          body: {'url': _url.text.trim()});
                                      if (!mounted) return;
                                      setState(() {
                                        _title.text =
                                            data['title'] as String? ?? '';
                                        _description.text =
                                            data['description'] as String? ??
                                                '';
                                        final amount =
                                            data['priceMinor'] as int?;
                                        _price.text = amount == null
                                            ? ''
                                            : (amount / 100).toStringAsFixed(2);
                                        if (data['currency'] != null &&
                                            ['RUB', 'USD', 'EUR']
                                                .contains(data['currency'])) {
                                          _currency = data['currency'];
                                        }
                                        if ((data['imagePath'] as String? ?? '')
                                            .isNotEmpty) {
                                          _image = data['imagePath'];
                                        }
                                      });
                                    } catch (error) {
                                      if (mounted) {
                                        messenger.showSnackBar(SnackBar(
                                            content:
                                                Text(s.errorMessage(error))));
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _picking = false);
                                      }
                                    }
                                  }),
                      Text(s.wishlistAutofillHint,
                          style: Theme.of(context).textTheme.bodySmall),
                      TextFormField(
                          key: const ValueKey('gift-price'),
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(labelText: s.giftPrice),
                          validator: (_) =>
                              _minor() == -1 ? s.wishlistInvalidPrice : null),
                      DropdownButtonFormField<String>(
                          key: ValueKey(_currency),
                          initialValue: _currency,
                          decoration:
                              InputDecoration(labelText: s.giftCurrency),
                          items: ['RUB', 'USD', 'EUR']
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) _currency = v;
                          }),
                      if (_image.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(children: [
                              const Icon(Icons.check_circle_outline),
                              Expanded(child: Text(s.giftPhoto)),
                              IconButton(
                                  onPressed: () => setState(() => _image = ''),
                                  icon: const Icon(Icons.close))
                            ])),
                      TextButton.icon(
                          onPressed: _picking
                              ? null
                              : () async {
                                  setState(() => _picking = true);
                                  final p = await widget.pickImage();
                                  if (mounted) {
                                    setState(() {
                                      _picking = false;
                                      if (p != null) _image = p;
                                    });
                                  }
                                },
                          icon: const Icon(Icons.photo_outlined),
                          label: Text(s.giftPhoto)),
                    ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          FilledButton(
              onPressed: _picking
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        Navigator.pop(
                            context,
                            WishlistItem(
                                id: widget.item?.id ?? WishlistItem.newId(),
                                title: _title.text.trim(),
                                description: _description.text.trim(),
                                productUrl: _url.text.trim(),
                                imagePath: _image,
                                priceMinor: _minor(),
                                currency: _currency));
                      }
                    },
              child: Text(s.save))
        ]);
  }
}
