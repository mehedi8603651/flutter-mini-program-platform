import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mini_program_tooling/mini_program_tooling.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption(
      'base-url',
      defaultsTo: 'http://127.0.0.1:8080/api/',
      help: 'Backend API base URL.',
    )
    ..addOption(
      'mini-program',
      help: 'Mini-program ID to inspect.',
      mandatory: true,
    )
    ..addOption('host-app', help: 'Host app identifier.')
    ..addOption('sdk-version', help: 'Host SDK version.')
    ..addOption('host-version', help: 'Host app version.')
    ..addOption('platform', help: 'Platform value sent to backend.')
    ..addOption('locale', help: 'Locale value sent to backend.')
    ..addOption('tenant-id', help: 'Optional tenant identifier.')
    ..addOption('pinned-version', help: 'Optional pinned mini-program version.')
    ..addOption(
      'capabilities',
      help: 'Comma-separated capability wire values.',
    )
    ..addOption(
      'request-id',
      help: 'Optional request ID to reuse as backend trace ID.',
    )
    ..addOption(
      'output',
      allowed: <String>['text', 'json'],
      defaultsTo: 'text',
      help: 'Output format.',
    );

  late final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (results.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }

  final request = DeliveryInspectionRequest(
    miniProgramId: results.option('mini-program')!,
    hostApp: results.option('host-app'),
    sdkVersion: results.option('sdk-version'),
    hostVersion: results.option('host-version'),
    platform: results.option('platform'),
    locale: results.option('locale'),
    tenantId: results.option('tenant-id'),
    pinnedVersion: results.option('pinned-version'),
    capabilities: _parseCapabilities(results.option('capabilities')),
  );

  final client = DeliveryInspectorClient(
    apiBaseUri: Uri.parse(results.option('base-url')!),
  );

  try {
    final response = await client.inspect(
      request,
      requestId: results.option('request-id'),
    );
    if (results.option('output') == 'json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(response.body));
    } else {
      stdout.writeln(formatDeliveryInspectionResponse(response));
    }

    if (response.statusCode >= HttpStatus.badRequest) {
      exitCode = 1;
    }
  } on SocketException catch (error) {
    stderr.writeln('Failed to reach backend: $error');
    exitCode = 1;
  } on HttpException catch (error) {
    stderr.writeln('HTTP error: $error');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('Invalid backend response: ${error.message}');
    exitCode = 1;
  }
}

Set<String> _parseCapabilities(String? rawCapabilities) {
  if (rawCapabilities == null || rawCapabilities.trim().isEmpty) {
    return const <String>{};
  }

  return rawCapabilities
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}
