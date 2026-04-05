import 'package:flutter/material.dart';

class NativeFeedbackDeskPage extends StatelessWidget {
  const NativeFeedbackDeskPage({super.key, required this.initialArgs});

  final Map<String, dynamic> initialArgs;

  @override
  Widget build(BuildContext context) {
    final source = initialArgs['source']?.toString() ?? 'unknown_source';
    final channel = initialArgs['channel']?.toString() ?? 'unknown_channel';

    return Scaffold(
      appBar: AppBar(title: const Text('Partner Feedback Desk')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partner-owned follow-up',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This page is native Flutter UI inside partner_app_host. '
                      'The same portable route alias is mapped to a different '
                      'partner-owned follow-up screen here.',
                    ),
                    const SizedBox(height: 16),
                    Text('Requested by: $source'),
                    Text('Channel: $channel'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, dynamic>{
                  'ticketCreated': true,
                  'source': source,
                  'channel': channel,
                });
              },
              child: const Text('Open partner follow-up ticket'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
