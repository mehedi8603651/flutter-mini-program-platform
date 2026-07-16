part of '../../../mp_screen_renderer.dart';

class _MpFormSubmitButton extends StatefulWidget {
  const _MpFormSubmitButton({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpFormSubmitButton> createState() => _MpFormSubmitButtonState();
}

class _MpFormSubmitButtonState extends State<_MpFormSubmitButton> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    final form = _MpFormScope.maybeOf(context);
    return AnimatedBuilder(
      animation: form ?? _NoopListenable.instance,
      builder: (context, _) {
        final submitting = form?.submitting == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _MpTapButton(
              label: submitting
                  ? 'Submitting...'
                  : widget.bindings.resolveString(
                      widget.node.props['label'] as String,
                    ),
              primary: true,
              enabled: form != null && !submitting,
              theme: widget.bindings.theme,
              onTap: form == null ? null : () => unawaited(_submit(form)),
            ),
            if (_message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _message!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _submit(_MpFormController form) async {
    if (form.submitting) {
      return;
    }
    if (!form.validate()) {
      setState(() => _message = 'Check the highlighted fields.');
      return;
    }
    form.setSubmitting(true);
    setState(() => _message = null);
    final formBindings = widget.bindings.copyWith(form: form.toBindingData());
    final rawBody =
        widget.node.props['body'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final body = rawBody.isEmpty
        ? form.values
        : formBindings.resolveMap(rawBody);
    final action = _MpAction(
      type: 'form.submit',
      props: <String, dynamic>{
        'endpoint': widget.node.props['endpoint'],
        if (widget.node.props['requestId'] != null)
          'requestId': widget.node.props['requestId'],
        'method': widget.node.props['method'],
        'body': body,
        if (widget.node.props['cacheTtlSeconds'] != null)
          'cacheTtlSeconds': widget.node.props['cacheTtlSeconds'],
      },
    );
    final result = await _MpActionDispatcher.dispatch(
      context,
      action,
      formBindings,
    );
    if (!mounted) {
      form.setSubmitting(false);
      return;
    }
    form.setSubmitting(false);
    final success = result is MiniProgramBackendResult && result.isSuccess;
    final nextAction = success
        ? widget.node.props['onSuccess'] as _MpAction?
        : widget.node.props['onError'] as _MpAction?;
    if (nextAction != null) {
      await _MpActionDispatcher.dispatch(context, nextAction, formBindings);
    }
    if (!success) {
      final message = result is MiniProgramBackendResult
          ? result.message ?? 'Form submission failed.'
          : 'Form submission failed.';
      setState(() => _message = message);
    }
  }
}
