import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/faq_content.dart';
import '../providers/locale_provider.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  Future<void> _openStore(BuildContext context, String url) async {
    final strings = context.readStrings;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Если магазин недоступен, пользователь сможет скопировать ссылку.
    }
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(strings.faqStoreUnavailable),
      action: SnackBarAction(
        label: strings.copy,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (!context.mounted) return;
          messenger
              .showSnackBar(SnackBar(content: Text(strings.faqLinkCopied)));
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(strings.faqTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(strings.faqSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 24),
                Text(strings.faqNfcSection,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: scheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NFC Tools · wakdev',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(strings.faqNfcToolsDescription),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openStore(context, nfcToolsAppStoreUrl),
                            icon: const Icon(Icons.apple),
                            label: const Text('App Store'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openStore(context, nfcToolsGooglePlayUrl),
                            icon: const Icon(Icons.shop_outlined),
                            label: const Text('Google Play'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                ...nfcFaq(strings.language).map(_entry),
                const SizedBox(height: 24),
                Text(strings.faqGeneralSection,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...generalFaq(strings.language).map(_entry),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entry(FaqEntry entry) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          key: PageStorageKey('faq-${entry.id}'),
          title: Text(entry.question),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: double.infinity,
                child: SelectionArea(child: Text(entry.answer))),
          ],
        ),
      );
}
