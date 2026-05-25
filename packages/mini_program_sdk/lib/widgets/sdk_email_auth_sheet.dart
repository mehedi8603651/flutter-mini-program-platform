import 'package:flutter/material.dart';

import '../auth/mini_program_auth.dart';
import '../network/mini_program_backend_connector.dart';

enum MiniProgramEmailAuthMode { signIn, signUp }

Future<MiniProgramAuthResult?> showMiniProgramEmailAuthSheet({
  required BuildContext context,
  required MiniProgramAuthController controller,
  required MiniProgramBackendConnector connector,
  required String miniProgramId,
  MiniProgramEmailAuthMode initialMode = MiniProgramEmailAuthMode.signIn,
}) {
  return showModalBottomSheet<MiniProgramAuthResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _MiniProgramEmailAuthSheet(
      controller: controller,
      connector: connector,
      miniProgramId: miniProgramId,
      initialMode: initialMode,
    ),
  );
}

class _MiniProgramEmailAuthSheet extends StatefulWidget {
  const _MiniProgramEmailAuthSheet({
    required this.controller,
    required this.connector,
    required this.miniProgramId,
    required this.initialMode,
  });

  final MiniProgramAuthController controller;
  final MiniProgramBackendConnector connector;
  final String miniProgramId;
  final MiniProgramEmailAuthMode initialMode;

  @override
  State<_MiniProgramEmailAuthSheet> createState() =>
      _MiniProgramEmailAuthSheetState();
}

class _MiniProgramEmailAuthSheetState
    extends State<_MiniProgramEmailAuthSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late MiniProgramEmailAuthMode _mode = widget.initialMode;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final email = _emailController.text;
    final password = _passwordController.text;
    MiniProgramAuthResult result;
    if (_mode == MiniProgramEmailAuthMode.signUp) {
      result = await widget.controller.signUpEmail(
        miniProgramId: widget.miniProgramId,
        connector: widget.connector,
        email: email,
        password: password,
      );
    } else {
      result = await widget.controller.signInEmail(
        miniProgramId: widget.miniProgramId,
        connector: widget.connector,
        email: email,
        password: password,
      );
    }

    _passwordController.clear();
    if (!mounted) {
      return;
    }
    if (result.success) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _submitting = false;
      _error = result.message ?? 'Email authentication failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<MiniProgramEmailAuthMode>(
              segments: const [
                ButtonSegment(
                  value: MiniProgramEmailAuthMode.signIn,
                  label: Text('Sign in'),
                ),
                ButtonSegment(
                  value: MiniProgramEmailAuthMode.signUp,
                  label: Text('Sign up'),
                ),
              ],
              selected: <MiniProgramEmailAuthMode>{_mode},
              onSelectionChanged: _submitting
                  ? null
                  : (values) {
                      setState(() {
                        _mode = values.single;
                        _error = null;
                      });
                    },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) {
                  return 'Email is required.';
                }
                if (!email.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !_submitting,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Password is required.';
                }
                if ((value ?? '').length < 6) {
                  return 'Use at least 6 characters.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _mode == MiniProgramEmailAuthMode.signUp
                          ? 'Create account'
                          : 'Sign in',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
