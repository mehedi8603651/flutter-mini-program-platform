import 'package:flutter/widgets.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:stac/stac.dart';


class SdkMiniProgramAuthBuilderModel {
  const SdkMiniProgramAuthBuilderModel({
    this.loading,
    this.signedOut,
    this.signedIn,
    this.error,
  });

  static const String typeName = 'miniProgramAuthBuilder';

  final Map<String, dynamic>? loading;
  final Map<String, dynamic>? signedOut;
  final Map<String, dynamic>? signedIn;
  final Map<String, dynamic>? error;

  factory SdkMiniProgramAuthBuilderModel.fromJson(Map<String, dynamic> json) {
    return SdkMiniProgramAuthBuilderModel(
      loading: _optionalWidgetJson(json['loading'], 'loading'),
      signedOut: _optionalWidgetJson(json['signedOut'], 'signedOut'),
      signedIn: _optionalWidgetJson(json['signedIn'], 'signedIn'),
      error: _optionalWidgetJson(json['error'], 'error'),
    );
  }

  static Map<String, dynamic>? _optionalWidgetJson(
    Object? value,
    String fieldName,
  ) {
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw FormatException('"$fieldName" must be a widget JSON object.');
    }
    return Map<String, dynamic>.from(value);
  }
}

class SdkMiniProgramAuthBuilderParser
    extends StacParser<SdkMiniProgramAuthBuilderModel> {
  const SdkMiniProgramAuthBuilderParser();

  @override
  String get type => SdkMiniProgramAuthBuilderModel.typeName;

  @override
  SdkMiniProgramAuthBuilderModel getModel(Map<String, dynamic> json) =>
      SdkMiniProgramAuthBuilderModel.fromJson(json);

  @override
  Widget parse(BuildContext context, SdkMiniProgramAuthBuilderModel model) {
    return _MiniProgramAuthBuilder(model: model);
  }
}

class _MiniProgramAuthBuilder extends StatelessWidget {
  const _MiniProgramAuthBuilder({required this.model});

  static const MiniProgramBackendBindingResolver _resolver =
      MiniProgramBackendBindingResolver();

  final SdkMiniProgramAuthBuilderModel model;

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final controller = scope?.authController;
    if (scope == null || controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, scope.backendStore]),
      builder: (context, _) {
        final snapshot = controller.snapshot(scope.miniProgramId);
        final template = _templateFor(snapshot);
        if (template == null) {
          return const SizedBox.shrink();
        }
        final resolved = _resolver.resolveTemplate(
          template,
          store: scope.backendStore,
          bindings: <String, dynamic>{'auth': snapshot.toBindingData()},
        );
        if (resolved is! Map) {
          return const SizedBox.shrink();
        }
        return Stac.fromJson(Map<String, dynamic>.from(resolved), context) ??
            const SizedBox.shrink();
      },
    );
  }

  Map<String, dynamic>? _templateFor(MiniProgramAuthSnapshot snapshot) {
    if (snapshot.loading) {
      return model.loading;
    }
    if (snapshot.authenticated) {
      return model.signedIn;
    }
    if (snapshot.hasError) {
      return model.error ?? model.signedOut;
    }
    return model.signedOut;
  }
}
