import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../../core/value_normalization.dart';
import '../shared/presentation_validation.dart';

/// QR code generation and host-controlled scanning helpers.
final class MpQr {
  const MpQr();

  /// Renders [value] as a QR code without using a host capability.
  ///
  /// The value may contain state bindings. Runtime validation prevents an
  /// oversized or otherwise unencodable value from crashing the screen.
  MpNode generate({
    required String value,
    num size = 240,
    num padding = 12,
    String errorCorrection = 'medium',
    String foregroundColor = '#000000',
    String backgroundColor = '#FFFFFF',
    String semanticLabel = 'QR code',
  }) {
    final normalizedValue = requiredWidgetString(value, 'value');
    if (!normalizedValue.contains('{{') && normalizedValue.length > 4096) {
      throw ArgumentError.value(
        value,
        'value',
        'Static QR values cannot exceed 4096 characters.',
      );
    }
    final normalizedSize = positiveWidgetNumber(size, 'size');
    if (normalizedSize < 96 || normalizedSize > 600) {
      throw ArgumentError.value(size, 'size', 'Size must be from 96 to 600.');
    }
    final normalizedPadding = nonNegativeWidgetNumber(padding, 'padding');
    if (normalizedPadding > 64 || normalizedPadding * 2 >= normalizedSize) {
      throw ArgumentError.value(
        padding,
        'padding',
        'Padding must be from 0 to 64 and leave space for the QR code.',
      );
    }
    return MpNode(
      'qrCode',
      props: <String, Object?>{
        'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
        'errorCorrection': allowedValue(
          errorCorrection,
          'errorCorrection',
          const <String>{'low', 'medium', 'quartile', 'high'},
        ),
        'foregroundColor': widgetColor(foregroundColor, 'foregroundColor'),
        'padding': normalizedPadding,
        'semanticLabel': requiredWidgetString(semanticLabel, 'semanticLabel'),
        'size': normalizedSize,
        'value': normalizedValue,
      },
    );
  }

  /// Opens the host's trusted QR scanner after an explicit user gesture.
  ///
  /// Scanned values are returned as inert data and are never opened or
  /// executed automatically.
  MpAction scan({
    bool allowTorch = true,
    Duration timeout = const Duration(seconds: 60),
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    final timeoutMs = boundedInt(
      timeout.inMilliseconds,
      'timeout',
      minimum: 1000,
      maximum: 120000,
    );
    return MpAction(
      'qr.scan',
      props: <String, Object?>{
        'allowTorch': allowTorch,
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        if (requestId != null)
          'requestId': stableAuthoringString(requestId, 'requestId'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        'targetState': requiredStateKey(targetState, 'targetState'),
        'timeoutMs': timeoutMs,
      },
    );
  }
}
