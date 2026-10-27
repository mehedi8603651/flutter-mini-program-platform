import 'dart:async';
import 'dart:io';

import 'phone_ai_model.dart';
import 'phone_ai_progress.dart';
import 'phone_ai_session.dart';

typedef PhoneAiDispatch =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

enum PhoneAiOutcome {
  idle,
  running,
  completed,
  needsInput,
  blocked,
  stopped,
  cancelled,
  limited,
  failed,
}

/// Reference-host run limits. Billing authority remains with the user's server
/// or provider: reported token/cost totals cannot bound an unreported charge.
class PhoneAiLimits {
  const PhoneAiLimits({
    this.maxDecisions = 16,
    this.maxTokens = 20000,
    this.maxReportedCostUsd = 0.05,
    this.maxNoProgressActions = 3,
    this.maxDuration = const Duration(minutes: 5),
    this.modelTimeout = const Duration(seconds: 90),
    this.screenTimeout = const Duration(seconds: 25),
    this.dispatchTimeout = const Duration(seconds: 10),
    this.observationInterval = const Duration(milliseconds: 350),
    this.actionInterval = const Duration(milliseconds: 250),
  });

  final int maxDecisions;
  final int maxTokens;
  final double maxReportedCostUsd;
  final int maxNoProgressActions;
  final Duration maxDuration;
  final Duration modelTimeout;
  final Duration screenTimeout;
  final Duration dispatchTimeout;
  final Duration observationInterval;
  final Duration actionInterval;

  void validate() {
    if (maxDecisions < 1 ||
        maxDecisions > 64 ||
        maxTokens < 1 ||
        !maxReportedCostUsd.isFinite ||
        maxReportedCostUsd <= 0 ||
        maxNoProgressActions < 2 ||
        maxNoProgressActions > 8 ||
        [
          maxDuration,
          modelTimeout,
          screenTimeout,
          dispatchTimeout,
        ].any((value) => value <= Duration.zero) ||
        observationInterval.isNegative ||
        actionInterval.isNegative) {
      throw ArgumentError('Invalid phone AI run limits.');
    }
  }
}

/// Host-owned orchestration; the SDK supplies observation and UI execution.
/// A user-initiated continuation always observes again and plans a new action.
class PhoneAiRunner extends PhoneAiSession {
  PhoneAiRunner({
    required this.appId,
    required this.dispatch,
    required this.isForeground,
    this.modelFactory = createPhoneAiModel,
    this.limits = const PhoneAiLimits(),
    this.allowHostHandoff = false,
    this.draft = '',
  }) {
    limits.validate();
  }

  final String appId;
  final PhoneAiDispatch dispatch;
  final bool Function() isForeground;
  final PhoneAiModelFactory modelFactory;
  @override
  final PhoneAiLimits limits;

  /// Only trusted host dispatch may supply nextAppId after opening a task.
  /// SDK-only runners remain locked to their original mounted session.
  final bool allowHostHandoff;
  @override
  String draft;
  @override
  bool running = false;
  @override
  PhoneAiOutcome outcome = PhoneAiOutcome.idle;
  @override
  String status = 'Ready';
  @override
  String message = '';
  @override
  String lastGoal = '';
  @override
  int decisions = 0;
  @override
  int tokens = 0;
  @override
  double? costUsd;
  @override
  final List<String> history = [];
  int _sequence = 0;
  bool _disposed = false;
  String? _lastSession;
  _Run? _active;

  @override
  bool get canContinue =>
      !running &&
      lastGoal.isNotEmpty &&
      outcome != PhoneAiOutcome.completed &&
      outcome != PhoneAiOutcome.idle;

  @override
  Future<void> start(String goal, {bool continuePrevious = false}) async {
    if (_disposed || running || goal.trim().isEmpty || goal.length > 1000) {
      return;
    }
    final resume = continuePrevious && lastGoal == goal.trim();
    if (!resume) {
      history.clear();
      _lastSession = null;
    }
    lastGoal = goal.trim();
    draft = goal.trim();
    final run = _Run(expectedAppId: appId.isEmpty ? null : appId);
    _active = run;
    running = true;
    outcome = PhoneAiOutcome.running;
    decisions = tokens = 0;
    costUsd = null;
    message = '';
    _update('Reading current screen');
    final progress = PhoneAiProgress(limit: limits.maxNoProgressActions);
    try {
      _check(run);
      run.model = modelFactory();
      for (var step = 0; step < limits.maxDecisions; step++) {
        final snapshot = await _ready(run);
        final session = snapshot['sessionId'] as String;
        if (run.session != null && run.session != session) {
          throw const _Stopped();
        }
        if (run.session == null) {
          // Old operation history belongs to its mounted session only.
          if (resume && _lastSession != session) history.clear();
          run.session = _lastSession = session;
        }
        final stuck = progress.inspect(snapshot);
        if (stuck != null) {
          _finish(
            run,
            PhoneAiOutcome.blocked,
            'AI paused — no progress',
            stuck,
          );
          return;
        }
        if (tokens >= limits.maxTokens ||
            (costUsd ?? 0) >= limits.maxReportedCostUsd) {
          throw const _RunLimit('The run reached its usage limit.');
        }
        decisions++;
        _update('Thinking — decision $decisions of ${limits.maxDecisions}');
        _check(run);
        final reply = await _wait(
          run.model!.decide(
            goal: lastGoal,
            snapshot: snapshot,
            progress: List.unmodifiable(history),
          ),
          run,
          limits.modelTimeout,
          'The AI request timed out. Check your connection and continue when ready.',
        );
        _check(run);
        tokens += reply.tokens;
        if (reply.costUsd != null) costUsd = (costUsd ?? 0) + reply.costUsd!;
        final decision = PhoneAiReply.validateDecision(
          reply.decision,
          snapshot,
        );
        final action = decision['action'] as String;
        if (phoneAiTerminalActions.contains(action)) {
          final current = await _ready(run);
          if (current['sessionId'] != session ||
              current['revision'] != snapshot['revision']) {
            throw const _Interrupted(
              'The screen changed while the AI was thinking. Continue to read it again.',
            );
          }
          final result = switch (action) {
            'done' => PhoneAiOutcome.completed,
            'needsInput' => PhoneAiOutcome.needsInput,
            _ => PhoneAiOutcome.blocked,
          };
          _finish(run, result, switch (result) {
            PhoneAiOutcome.completed => 'AI completed — check the result',
            PhoneAiOutcome.needsInput => 'Needs your input',
            _ => 'AI cannot continue',
          }, decision['message'] as String);
          return;
        }
        final target = (snapshot['nodes'] as List).cast<Map>().where(
          (node) => node['id'] == decision['targetId'],
        );
        final label = target.isEmpty
            ? ''
            : '${target.first['label'] ?? ''}'.split('\n').first;
        final operation =
            '$action ${label.length > 80 ? label.substring(0, 80) : label}'
                .trim();
        _record('$operation: outcome not yet confirmed');
        _update('Applying $action');
        _check(run);
        final result = await _wait(
          dispatch({
            'method': 'interact',
            'request': {
              'requestId':
                  'phone-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}',
              'sessionId': session,
              'revision': snapshot['revision'],
              ...decision,
            },
          }),
          run,
          limits.dispatchTimeout,
          'The action outcome is uncertain. Check the screen before continuing; it may already have happened.',
        );
        _check(run);
        history[history.length - 1] = '$operation: ${result['status']}';
        if (result['status'] != 'completed' && result['status'] != 'pending') {
          throw _Interrupted(switch (result['code']) {
            'stale_view' =>
              'The screen changed while the AI was thinking. No action was applied; continue to read it again.',
            'foreground_required' =>
              'The mini-program lost foreground focus. Return to it before continuing.',
            'target_unavailable' =>
              'The selected control is no longer available. Continue to read the current screen.',
            'render_pending' =>
              'The screen was still rendering. Continue after it finishes.',
            'back_unavailable' => 'Back is unavailable on the current screen.',
            _ =>
              'The action failed or was interrupted. Check its result before continuing.',
          });
        }
        final nextAppId = result['nextAppId'];
        if (allowHostHandoff && nextAppId is String && nextAppId.isNotEmpty) {
          run.handoffFromAppId = snapshot['appId'] as String;
          run.expectedAppId = nextAppId;
          run.session = null;
        }
        _update(
          result['status'] == 'pending'
              ? 'Waiting for the screen'
              : 'Decision $decisions applied',
        );
        await _wait(
          Future<void>.delayed(limits.actionInterval),
          run,
          limits.dispatchTimeout,
          'The screen did not settle.',
        );
      }
      throw _RunLimit(
        'Stopped at the ${limits.maxDecisions}-decision run limit.',
      );
    } on _Stopped {
      _finish(
        run,
        PhoneAiOutcome.stopped,
        allowHostHandoff
            ? 'Paused — the active screen changed'
            : 'Stopped — mini-program is not active',
        allowHostHandoff
            ? 'Return to the host or mini-program and continue from its current screen.'
            : 'Return to this mini-program to continue from its current screen.',
      );
    } on _RunLimit catch (error) {
      _finish(
        run,
        PhoneAiOutcome.limited,
        'AI paused — run limit reached',
        error.message,
      );
    } on _Interrupted catch (error) {
      _finish(
        run,
        PhoneAiOutcome.stopped,
        'AI paused — check the screen',
        error.message,
      );
    } on PhoneAiHttpFailure catch (error) {
      final reason = switch (error.status) {
        401 => 'API key was rejected (HTTP 401)',
        402 => 'OpenRouter credit limit reached (HTTP 402)',
        429 => 'OpenRouter rate limit reached (HTTP 429)',
        _ => 'OpenRouter request failed (HTTP ${error.status})',
      };
      _finish(
        run,
        PhoneAiOutcome.failed,
        reason,
        'Check the provider connection before continuing.',
      );
    } on SocketException {
      _finish(
        run,
        PhoneAiOutcome.failed,
        'Cannot reach OpenRouter',
        'Check phone Internet/VPN, then continue from the current screen.',
      );
    } on HandshakeException {
      _finish(
        run,
        PhoneAiOutcome.failed,
        'Secure connection failed',
        'Check the phone network and date/time before continuing.',
      );
    } on FormatException {
      _finish(
        run,
        PhoneAiOutcome.failed,
        'AI returned an invalid decision',
        'No further action was applied. Continue to ask for a new decision.',
      );
    } on Object {
      _finish(
        run,
        PhoneAiOutcome.failed,
        'AI request could not finish',
        'Check the screen before continuing.',
      );
    } finally {
      run.close();
      if (identical(_active, run)) {
        _active = null;
        running = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> _ready(_Run run) async {
    final waiting = Stopwatch()..start();
    Map<String, dynamic>? previous;
    do {
      _check(run);
      final snapshot = await _wait(
        dispatch({'method': 'observe'}),
        run,
        limits.dispatchTimeout,
        'The current screen could not be read. Check it before continuing.',
      );
      _check(run);
      if (snapshot['status'] == 'ready') {
        final observedAppId = snapshot['appId'];
        if (observedAppId is! String || observedAppId.isEmpty) {
          throw const _Stopped();
        }
        run.expectedAppId ??= observedAppId;
        if (observedAppId != run.expectedAppId) {
          if (observedAppId != run.handoffFromAppId) throw const _Stopped();
          // startActivity returns before the new window gains focus. Do not
          // ask the model about the old host screen while that launch settles.
          previous = null;
          await _wait(
            Future<void>.delayed(limits.observationInterval),
            run,
            limits.dispatchTimeout,
            'The mini-program task did not open.',
          );
          continue;
        }
        run.handoffFromAppId = null;
        // Keep the observed revision; never refresh an outdated model command.
        if (previous?['revision'] == snapshot['revision'] &&
            previous?['sessionId'] == snapshot['sessionId']) {
          return snapshot;
        }
        previous = snapshot;
      } else {
        previous = null;
        if (snapshot['status'] != 'pending') throw const _Stopped();
        _update('Waiting for the screen');
      }
      await _wait(
        Future<void>.delayed(limits.observationInterval),
        run,
        limits.dispatchTimeout,
        'The screen did not settle.',
      );
    } while (waiting.elapsed < limits.screenTimeout);
    throw const _Interrupted(
      'The screen is still loading or changing. Continue when it is ready; the previous action was not repeated.',
    );
  }

  Future<T> _wait<T>(
    Future<T> work,
    _Run run,
    Duration timeout,
    String reason,
  ) async {
    _check(run);
    final remaining = limits.maxDuration - run.clock.elapsed;
    final runDeadline = remaining <= timeout;
    try {
      final result = await Future.any<T>([
        work,
        run.cancelled.future.then<T>((_) => throw const _Stopped()),
      ]).timeout(runDeadline ? remaining : timeout);
      _check(run);
      return result;
    } on TimeoutException {
      _check(run);
      if (runDeadline) {
        throw const _RunLimit(
          'The run reached its time limit. Check the screen before continuing.',
        );
      }
      throw _Interrupted(reason);
    }
  }

  void _check(_Run run) {
    if (_disposed || !identical(_active, run) || !isForeground()) {
      throw const _Stopped();
    }
    if (run.clock.elapsed >= limits.maxDuration) {
      throw const _RunLimit(
        'The run reached its time limit. Check the screen before continuing.',
      );
    }
  }

  void _record(String entry) {
    history.add(entry);
    if (history.length > 8) history.removeAt(0);
  }

  void _finish(_Run run, PhoneAiOutcome result, String title, String detail) {
    if (_disposed || !identical(_active, run)) return;
    outcome = result;
    message = detail;
    _update(title);
  }

  void _update(String value) {
    status = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void updateDraft(String value) {
    if (_disposed || value.length > 1000 || draft == value) return;
    draft = value;
    notifyListeners();
  }

  @override
  void stop([String reason = 'Stopped by you']) {
    final run = _active;
    if (run == null) return;
    _active = null;
    run.close();
    running = false;
    outcome = PhoneAiOutcome.stopped;
    message =
        'Continue will read the current screen again. Check any action already in progress before continuing.';
    _update(reason);
  }

  /// Explicitly end an active or paused task. A later Start gets a fresh goal
  /// context, while already applied UI changes and the editable draft remain.
  @override
  void cancel() {
    if (_disposed || (!running && !canContinue)) return;
    final run = _active;
    _active = null;
    run?.close();
    running = false;
    outcome = PhoneAiOutcome.cancelled;
    lastGoal = '';
    _lastSession = null;
    message =
        'No more AI actions will run. Changes already made remain on screen. '
        'Start AI begins a new task from the current screen.';
    _update('AI task cancelled');
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

class _Run {
  _Run({required this.expectedAppId});

  String? expectedAppId;
  String? handoffFromAppId;
  final clock = Stopwatch()..start();
  final cancelled = Completer<void>();
  PhoneAiModel? model;
  String? session;
  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    clock.stop();
    cancelled.complete();
    model?.close();
  }
}

class _Stopped implements Exception {
  const _Stopped();
}

class _Interrupted implements Exception {
  const _Interrupted(this.message);
  final String message;
}

class _RunLimit implements Exception {
  const _RunLimit(this.message);
  final String message;
}
