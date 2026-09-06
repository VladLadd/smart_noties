import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'note_edit_screen.dart';
import 'note_view_screen.dart';
import 'profile_screen.dart';
import '../providers/notes_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../models/note_model.dart';
import '../services/api_config.dart';
import '../services/nfc_reader_service.dart';

class NotesGridScreen extends StatefulWidget {
  const NotesGridScreen({super.key});

  @override
  State<NotesGridScreen> createState() => _NotesGridScreenState();
}

class _NotesGridScreenState extends State<NotesGridScreen> {
  final _nfcReader = NfcReaderService();
  bool _showGrid = true;
  bool _readingNfc = false;

  @override
  void dispose() {
    _nfcReader.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildNotes()),
                _buildBottomBar(),
              ],
            ),
            _buildFabMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes() {
    final notes = context.watch<NotesProvider>().notes;
    if (notes.isEmpty) return _buildEmptyState();

    if (!_showGrid) {
      return ListView.separated(
        itemCount: notes.length,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final note = notes[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openNote(note),
            onLongPress: () => _showNoteActions(note),
            child: _buildNoteRow(note),
          );
        },
      );
    }

    return _buildMasonryGrid(notes);
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.noNotesTitle,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              fontFamily: 'Georgia',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.noNotesSubtitle,
            style: TextStyle(
              fontSize: 18,
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const Spacer(),
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 28, bottom: 40),
              child: Icon(Icons.arrow_downward, size: 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasonryGrid(List<Note> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columnWidth = (constraints.maxWidth - spacing * 3) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(spacing, spacing, spacing, 88),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: columnWidth,
                child: _buildMasonryColumn(notes, 0, columnWidth),
              ),
              const SizedBox(width: spacing),
              SizedBox(
                width: columnWidth,
                child: _buildMasonryColumn(notes, 1, columnWidth),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasonryColumn(
    List<Note> notes,
    int startIndex,
    double columnWidth,
  ) {
    final children = <Widget>[];
    for (var index = startIndex; index < notes.length; index += 2) {
      final note = notes[index];
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: _masonryTileHeight(index, columnWidth),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openNote(note),
              onLongPress: () => _showNoteActions(note),
              child: _buildNoteTile(note),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  double _masonryTileHeight(int index, double width) {
    const ratios = [1.56, 1.08, 1.35, 1.72, 1.2, 1.46];
    final ratio = ratios[index % ratios.length];
    return (width * ratio).clamp(132.0, 280.0).toDouble();
  }

  Future<void> _openNote(Note note) async {
    final notesProvider = context.read<NotesProvider>();
    final authToken = context.read<AuthProvider>().token;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var noteToOpen = note;
    if (note.hasProtection) {
      final password = await _showProtectedNoteDialog();
      if (password == null) return;
      if (!mounted) return;

      try {
        noteToOpen = await notesProvider.verifyNotePassword(
          note,
          password: password,
          token: authToken,
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
        );
        return;
      }
    }

    if (!mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => NoteViewScreen(
          note: noteToOpen,
          initiallyUnlocked: noteToOpen.hasProtection,
        ),
      ),
    );
  }

  Future<String?> _showProtectedNoteDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _ProtectedNotePasswordDialog(),
    );
  }

  void _showNoteActions(Note note) {
    final strings = context.readStrings;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(strings.edit),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteEditScreen(initialNote: note),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                strings.delete,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteDialog(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Note note) {
    final strings = context.readStrings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteNoteQuestion),
        content: Text(
          note.title.isNotEmpty ? '«${note.title}»' : strings.noteWillBeDeleted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<NotesProvider>();
              final token = context.read<AuthProvider>().token;
              Navigator.pop(ctx);
              provider.deleteNote(note.id, token: token).catchError((e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$e'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              });
            },
            child: Text(
              strings.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(Note note) {
    final imageProvider = _noteImageProvider(note);
    final strings = context.strings;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: note.color.withValues(alpha: 0.85),
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          if (note.hasProtection)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    strings.protectedNoteMultiline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (note.hasProtection)
            Positioned(
              top: 0,
              right: note.isPending ? 24 : 0,
              child: Tooltip(
                message: strings.protectedNote,
                child: const Icon(Icons.lock, size: 18),
              ),
            ),
          if (!note.hasProtection && note.title.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _plainTextPreview(note.body),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          if (note.isPending)
            Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: strings.notUploaded,
                child: const Icon(
                  Icons.cloud_off,
                  size: 18,
                  color: Colors.orange,
                ),
              ),
            ),
          if (!note.hasProtection && (note.isVoice || note.isVideo))
            Positioned(
              bottom: 0,
              right: 0,
              child: _MediaBadges(note: note, compact: true),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(Note note) {
    final imageProvider = _noteImageProvider(note);
    final strings = context.strings;
    final title = note.hasProtection
        ? strings.protectedNote
        : (note.title.isNotEmpty ? note.title : strings.noTitle);
    final body = note.hasProtection
        ? strings.enterPasswordToView
        : _plainTextPreview(note.body);

    return Container(
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: note.color.withValues(alpha: 0.85),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              color: Colors.black.withValues(alpha: 0.08),
              child: imageProvider != null
                  ? Image(image: imageProvider, fit: BoxFit.cover)
                  : Icon(
                      note.hasProtection
                          ? Icons.lock_outline
                          : Icons.sticky_note_2_outlined,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                    if (note.hasProtection) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: strings.protectedNote,
                        child: const Icon(Icons.lock, size: 18),
                      ),
                    ],
                    if (note.isPending) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: strings.notUploaded,
                        child: const Icon(
                          Icons.cloud_off,
                          size: 18,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body.isNotEmpty ? body : strings.noText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          if (!note.hasProtection && (note.isVoice || note.isVideo)) ...[
            const SizedBox(width: 8),
            _MediaBadges(note: note),
          ],
        ],
      ),
    );
  }

  ImageProvider? _noteImageProvider(Note note) {
    if (note.hasProtection || note.imagePath == null) return null;

    final path = note.imagePath!;
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    if (isRemoteMedia(path)) {
      final token = context.read<AuthProvider>().token;
      return NetworkImage(
        resolveMediaUrl(path),
        headers: token == null || token.isEmpty
            ? null
            : {'Authorization': 'Bearer $token'},
      );
    }
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }

  String _plainTextPreview(String markdown) {
    return markdown
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[*_`>#-]'), '')
        .replaceAll(RegExp(r'\[[ xX]\]'), '')
        .trim();
  }

  Widget _buildBottomBar() {
    final notesProvider = context.watch<NotesProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomNavButton(
            label: context.strings.profile.toUpperCase(),
            icon: Icons.person,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          _HiddenNotesButton(
            active: notesProvider.isHiddenNotesVisible,
            loading: _readingNfc || notesProvider.unlockingHiddenNotes,
            remaining: notesProvider.hiddenSessionRemaining,
            onPressed: _toggleHiddenNotes,
          ),
          IconButton(
            tooltip:
                _showGrid ? context.strings.showList : context.strings.showGrid,
            icon: Icon(_showGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHiddenNotes() async {
    if (_readingNfc) return;

    final notesProvider = context.read<NotesProvider>();
    final token = context.read<AuthProvider>().token;

    if (notesProvider.isHiddenNotesVisible) {
      await notesProvider.lockHiddenNotes(token: token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.readStrings.hiddenNotesHidden)),
      );
      return;
    }

    var dialogOpen = true;
    setState(() => _readingNfc = true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _NfcWaitingDialog(
            onCancel: () {
              _nfcReader.cancel();
              Navigator.pop(dialogContext);
            },
          );
        },
      ).whenComplete(() => dialogOpen = false),
    );

    try {
      await Future<void>.delayed(Duration.zero);
      final payload = await _nfcReader.readUnlockPayload();
      if (!mounted) return;
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();

      await notesProvider.unlockHiddenNotes(
        payload: payload,
        token: token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.readStrings.hiddenNotesOpened)),
      );
    } catch (e) {
      if (!mounted) return;
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      if (!e.toString().contains('Сканирование отменено')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _readingNfc = false);
    }
  }

  Widget _buildFabMenu() {
    return Positioned(
      bottom: 60,
      right: 24,
      child: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditScreen()),
        ),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}

class _MediaBadges extends StatelessWidget {
  final Note note;
  final bool compact;

  const _MediaBadges({
    required this.note,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[
      if (note.isVoice) Icons.mic,
      if (note.isVideo) Icons.video_library_outlined,
    ];
    if (icons.isEmpty) return const SizedBox.shrink();

    final iconWidgets = icons
        .map(
          (icon) => Icon(
            icon,
            size: compact ? 14 : 20,
            color: compact ? Colors.white : Colors.black87,
          ),
        )
        .toList();

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < iconWidgets.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          iconWidgets[i],
        ],
      ],
    );

    if (!compact) return content;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: content,
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _BottomNavButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _HiddenNotesButton extends StatelessWidget {
  final bool active;
  final bool loading;
  final Duration remaining;
  final VoidCallback onPressed;

  const _HiddenNotesButton({
    required this.active,
    required this.loading,
    required this.remaining,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = active
        ? context.strings.hideHiddenWithRemaining(_formatRemaining(remaining))
        : context.strings.showHiddenByNfc;
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(active ? Icons.visibility : Icons.visibility_off),
    );
  }

  String _formatRemaining(Duration value) {
    if (value <= Duration.zero) return '0:00';
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _NfcWaitingDialog extends StatelessWidget {
  final VoidCallback onCancel;

  const _NfcWaitingDialog({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.nfcWaitingTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          Text(
            context.strings.nfcWaitingMessage,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(context.strings.cancel),
        ),
      ],
    );
  }
}

class _ProtectedNotePasswordDialog extends StatefulWidget {
  const _ProtectedNotePasswordDialog();

  @override
  State<_ProtectedNotePasswordDialog> createState() =>
      _ProtectedNotePasswordDialogState();
}

class _ProtectedNotePasswordDialogState
    extends State<_ProtectedNotePasswordDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.protectedNote),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.strings.enterPasswordToReadNote),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.strings.password,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _passwordCtrl.text),
          child: Text(context.strings.open),
        ),
      ],
    );
  }
}
