import 'package:flutter/foundation.dart';

import 'phone_ai_runner.dart' show PhoneAiLimits, PhoneAiOutcome;

/// Host-owned assistant state shared by the foreground host/task views.
/// A task view may be a remote client; it never needs its own model client.
abstract class PhoneAiSession extends ChangeNotifier {
  bool get running;
  bool get canContinue;
  PhoneAiOutcome get outcome;
  String get status;
  String get message;
  String get lastGoal;
  String get draft;
  List<String> get history;
  int get decisions;
  int get tokens;
  double? get costUsd;
  PhoneAiLimits get limits;

  void updateDraft(String value);
  Future<void> start(String goal, {bool continuePrevious = false});
  void stop([String reason = 'Paused by you']);
  void cancel();
}
