import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note_model.dart';
import '../models/wishlist_model.dart';
import '../providers/locale_provider.dart';
import '../services/api_config.dart';

Widget wishlistImage(String path,
    {String? token, String? password, double height = 180}) {
  final headers = <String, String>{
    if (token != null) 'Authorization': 'Bearer $token',
    if (password != null) 'X-Media-Password': password
  };
  final ImageProvider provider = isRemoteMedia(path)
      ? NetworkImage(resolveMediaUrl(path), headers: headers)
      : kIsWeb
          ? NetworkImage(path)
          : FileImage(File(path));
  return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image(
          image: provider,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
              height: height,
              child: const Center(child: Icon(Icons.broken_image_outlined)))));
}

class GiftCard extends StatelessWidget {
  final WishlistItem item;
  final Note note;
  final String? token;
  final Widget? actions;
  final String? mediaNoteId;
  const GiftCard(
      {super.key,
      required this.item,
      required this.note,
      this.token,
      this.actions,
      this.mediaNoteId});
  @override
  Widget build(BuildContext context) => Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (item.imagePath.isNotEmpty) ...[
              wishlistImage(
                  mediaNoteId == null ||
                          !item.imagePath.startsWith('/api/image/')
                      ? item.imagePath
                      : '/api/notes/$mediaNoteId/wishlist/team-image/${Uri.parse(item.imagePath).pathSegments.last}',
                  token: token,
                  password: note.protectionPassword),
              const SizedBox(height: 12)
            ],
            Row(children: [
              Expanded(
                  child: Text(item.title,
                      style: Theme.of(context).textTheme.titleLarge)),
              if (actions != null) actions!
            ]),
            if (item.priceMinor != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '${(item.priceMinor! / 100).toStringAsFixed(2)} ${item.currency}',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            if (item.description.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(item.description)),
            if (item.productUrl.isNotEmpty)
              TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(context.strings.viewStore),
                  onPressed: () async {
                    final uri = Uri.tryParse(item.productUrl);
                    if (uri == null ||
                        !['http', 'https'].contains(uri.scheme) ||
                        uri.host.isEmpty) {
                      return;
                    }
                    try {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(context.readStrings.wishlistInvalidURL)));
                      }
                    }
                  }),
          ])));
}

Future<bool> wishlistConfirm(BuildContext context, String message,
        {String? action}) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(content: Text(message), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.readStrings.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(action ?? context.readStrings.confirm)),
            ])) ??
    false;
