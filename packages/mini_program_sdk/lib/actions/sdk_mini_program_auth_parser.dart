import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import '../auth/mini_program_auth.dart';
import '../sdk_context.dart';
import '../widgets/sdk_email_auth_sheet.dart';
import 'sdk_mini_program_auth_action.dart';

class SdkMiniProgramAuthParser
    extends StacActionParser<SdkMiniProgramAuthAction> {
  const SdkMiniProgramAuthParser();

  @override
  String get actionType => SdkMiniProgramAuthAction.stacActionType;

  @override
  SdkMiniProgramAuthAction getModel(Map<String, dynamic> json) =>
      SdkMiniProgramAuthAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(
    BuildContext context,
    SdkMiniProgramAuthAction model,
  ) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return _failure('Mini-program SDK scope is unavailable.');
    }
    final controller = scope.authController;
    if (controller == null) {
      return _failure(
        'Mini-program auth is not configured.',
        errorCode: 'mini_program_auth_not_configured',
      );
    }

    final connector = scope.backendConnector;
    if (model.isShowEmailAuth) {
      if (connector == null) {
        return _failure(
          'Publisher backend is not configured for email auth.',
          errorCode: 'publisher_backend_not_configured',
        );
      }
      final result = await showMiniProgramEmailAuthSheet(
        context: context,
        controller: controller,
        connector: connector,
        miniProgramId: scope.miniProgramId,
        initialMode: model.mode == 'signUp'
            ? MiniProgramEmailAuthMode.signUp
            : MiniProgramEmailAuthMode.signIn,
      );
      return result?.toJson() ??
          MiniProgramAuthResult(
            success: false,
            snapshot: controller.snapshot(scope.miniProgramId),
            message: 'Email auth was cancelled.',
            errorCode: 'auth_cancelled',
          ).toJson();
    }

    if (model.isSignOut) {
      return (await controller.signOut(
        miniProgramId: scope.miniProgramId,
        connector: connector,
      )).toJson();
    }
    if (model.isRestore) {
      return (await controller.restore(
        miniProgramId: scope.miniProgramId,
        connector: connector,
      )).toJson();
    }
    if (model.isRefresh) {
      if (connector == null) {
        return _failure(
          'Publisher backend is not configured for auth refresh.',
          errorCode: 'publisher_backend_not_configured',
        );
      }
      return (await controller.refresh(
        miniProgramId: scope.miniProgramId,
        connector: connector,
      )).toJson();
    }

    return _failure(
      'Unsupported mini-program auth action "${model.action}".',
      errorCode: 'unsupported_auth_action',
    );
  }

  Map<String, dynamic> _failure(String message, {String? errorCode}) {
    return <String, dynamic>{
      'success': false,
      'authenticated': false,
      'status': 'error',
      'message': message,
      'errorCode': errorCode ?? 'mini_program_auth_failed',
    };
  }
}
