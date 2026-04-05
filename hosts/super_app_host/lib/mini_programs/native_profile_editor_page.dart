import 'package:flutter/material.dart';

class NativeProfileEditorPage extends StatelessWidget {
  const NativeProfileEditorPage({super.key, required this.initialArgs});

  final Map<String, dynamic> initialArgs;

  @override
  Widget build(BuildContext context) {
    final userId = initialArgs['userId']?.toString() ?? 'unknown_user';
    final source = initialArgs['source']?.toString() ?? 'unknown_source';

    return Scaffold(
      appBar: AppBar(title: const Text('Native Profile Editor')),
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
                      'Host-owned edit flow',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This page is native Flutter UI inside super_app_host. '
                      'The mini-program requested it through HostBridge.',
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
                  'saved': true,
                  'userId': userId,
                  'source': source,
                });
              },
              child: const Text('Save profile changes'),
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
