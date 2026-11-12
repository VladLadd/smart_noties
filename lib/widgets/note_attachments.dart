import 'package:flutter/material.dart';
import '../providers/locale_provider.dart';
import '../services/open_attachment.dart';

class NoteAttachments extends StatelessWidget {
  final List<String> paths;
  final String? token;
  final String? password;
  const NoteAttachments(
      {super.key, required this.paths, this.token, this.password});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final path in paths)
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(
                (Uri.tryParse(path)?.pathSegments.lastOrNull ?? path)
                    .replaceFirst(
                        RegExp(r'^[a-f0-9]{32}_|^[0-9]+_[0-9]+_'), ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            onTap: () async {
              final name = (Uri.tryParse(path)?.pathSegments.lastOrNull ??
                      'attachment')
                  .replaceFirst(RegExp(r'^[a-f0-9]{32}_|^[0-9]+_[0-9]+_'), '');
              try {
                await openAttachment(path,
                    name: name, token: token, password: password);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(context.readStrings.attachmentOpenFailed)));
                }
              }
            },
          ),
      ]);
}
