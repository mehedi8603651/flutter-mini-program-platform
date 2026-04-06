import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../mini_program_failure.dart';

/// Default fallback error view when a mini-program cannot be loaded or rendered.
class SdkErrorView extends StatelessWidget {
  const SdkErrorView({super.key, required this.failure});

  final MiniProgramFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diagnostics = _buildDiagnostics(failure.details);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _titleForFailure(failure),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                failure.displayMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (failure.errorCode != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Error code: ${failure.errorCode}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (diagnostics.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final line in diagnostics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _titleForFailure(MiniProgramFailure failure) {
    final errorCode = failure.errorCode;
    final cacheExpired =
        failure.details['manifestCacheExpired'] == true ||
        failure.details['entryScreenCacheExpired'] == true;

    switch (errorCode) {
      case MiniProgramErrorCodes.backendUnreachable:
      case MiniProgramErrorCodes.backendTimeout:
        if (cacheExpired) {
          return 'Offline copy unavailable';
        }
        return 'Backend unavailable';
      case MiniProgramErrorCodes.secureApiSessionMissing:
      case MiniProgramErrorCodes.secureApiSessionExpired:
      case MiniProgramErrorCodes.secureApiUnauthorized:
        return 'Sign-in required';
      case MiniProgramErrorCodes.secureApiForbidden:
      case MiniProgramErrorCodes.secureApiNotAllowlisted:
        return 'Secure request blocked';
      case MiniProgramErrorCodes.secureApiInvalidPayload:
      case MiniProgramErrorCodes.secureApiValidationFailed:
        return 'Secure request invalid';
      case 'host_not_enabled':
      case 'delivery_rule_disabled':
      case 'manifest_context_required':
        return 'Release unavailable';
      case 'unsupported_sdk_version':
      case 'incompatible_sdk_version':
        return 'SDK update required';
      case 'missing_capabilities':
      case 'unsupported_capability':
        return 'Host capability mismatch';
      case 'artifact_not_found':
        return 'Release artifact missing';
      default:
        return 'Mini-program unavailable';
    }
  }

  static List<String> _buildDiagnostics(Map<String, dynamic> details) {
    final diagnostics = <String>[];

    final requestedPinnedVersion = details['requestedPinnedVersion'];
    if (requestedPinnedVersion is String && requestedPinnedVersion.isNotEmpty) {
      diagnostics.add('Pinned version: $requestedPinnedVersion');
    }

    final resolvedVersion = details['resolvedVersion'];
    if (resolvedVersion is String && resolvedVersion.isNotEmpty) {
      diagnostics.add('Resolved version: $resolvedVersion');
    }

    final matchedRuleId = details['matchedRuleId'];
    if (matchedRuleId is String && matchedRuleId.isNotEmpty) {
      diagnostics.add('Matched rule: $matchedRuleId');
    }

    final decisionReason = details['decisionReason'];
    if (decisionReason is String && decisionReason.isNotEmpty) {
      diagnostics.add('Decision reason: $decisionReason');
    }

    if (details['manifestCacheExpired'] == true ||
        details['entryScreenCacheExpired'] == true) {
      diagnostics.add(
        'Cached offline copy is older than the allowed stale window.',
      );
    }

    final missingCapabilities = details['missingCapabilities'];
    if (missingCapabilities is Iterable) {
      final values = missingCapabilities
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        diagnostics.add('Missing capabilities: ${values.join(', ')}');
      }
    }

    final deliveryContext = details['deliveryContext'];
    if (deliveryContext is Map) {
      final hostApp = deliveryContext['hostApp'];
      if (hostApp is String && hostApp.isNotEmpty) {
        diagnostics.add('Host app: $hostApp');
      }
    } else {
      final hostApp = details['hostApp'];
      if (hostApp is String && hostApp.isNotEmpty) {
        diagnostics.add('Host app: $hostApp');
      }
    }

    final traceId = details['traceId'] ?? details['backendTraceId'];
    if (traceId is String && traceId.isNotEmpty) {
      diagnostics.add('Trace ID: $traceId');
    }

    return diagnostics;
  }
}
