import 'package:flutter/material.dart';

class NativeProfileReviewPage extends StatelessWidget {
  const NativeProfileReviewPage({super.key, required this.initialArgs});

  final Map<String, dynamic> initialArgs;

  @override
  Widget build(BuildContext context) {
    final userId = initialArgs['userId']?.toString() ?? 'unknown_user';
    final source = initialArgs['source']?.toString() ?? 'unknown_source';

    return Scaffold(
      appBar: AppBar(title: const Text('Partner Profile Review')),
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
                      'Partner-owned account step',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This page is native Flutter UI inside partner_app_host. '
                      'The same mini-program route alias is mapped to a '
                      'different host-owned screen here.',
                    ),
                    const SizedBox(height: 16),
                    Text('User ID: $userId'),
                    Text('Requested by: $source'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, dynamic>{
                  'approved': true,
                  'userId': userId,
                  'source': source,
                });
              },
              child: const Text('Apply partner-side update'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
