import 'package:stac_core/stac_core.dart';

import '../components/feedback_expectations_card.dart';

@StacScreen(screenName: 'feedback_form_home')
StacWidget feedbackFormHome() {
  return StacScaffold(
    appBar: StacAppBar(title: StacText(data: 'Feedback Form')),
    body: StacSafeArea(
      child: StacSingleChildScrollView(
        padding: StacEdgeInsets.all(24),
        child: StacForm(
          autovalidateMode: StacAutovalidateMode.onUserInteraction,
          child: StacColumn(
            crossAxisAlignment: StacCrossAxisAlignment.start,
            children: [
              StacText(
                data: 'Portable feedback lane',
                style: StacCustomTextStyle(
                  fontSize: 28,
                  fontWeight: StacFontWeight.w700,
                  color: '#1A202C',
                ),
              ),
              StacSizedBox(height: 12),
              StacText(
                data:
                    'This second mini-program stays inside the current MVP '
                    'capabilities: validate locally, track an event through the '
                    'host bridge, and open a host-owned follow-up screen.',
              ),
              StacSizedBox(height: 16),
              StacContainer(
                padding: StacEdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: StacBoxDecoration(
                  color: '#E0F2FE',
                  borderRadius: StacBorderRadius.all(18),
                ),
                child: StacText(
                  data: 'Release lane: Feedback Form v1.0.0',
                  style: StacCustomTextStyle(
                    fontSize: 15,
                    fontWeight: StacFontWeight.w600,
                    color: '#0C4A6E',
                  ),
                ),
              ),
              StacSizedBox(height: 16),
              feedbackExpectationsCard(),
              StacSizedBox(height: 24),
              StacText(
                data: 'Feedback topic',
                style: StacCustomTextStyle(
                  fontSize: 16,
                  fontWeight: StacFontWeight.w600,
                ),
              ),
              StacSizedBox(height: 10),
              StacWrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _topicChip('Performance'),
                  _topicChip('Missing feature'),
                  _topicChip('UI polish'),
                  _topicChip('General suggestion'),
                ],
              ),
              StacSizedBox(height: 24),
              StacTextFormField(
                id: 'contact_hint',
                decoration: const StacInputDecoration(
                  labelText: 'Contact hint (optional)',
                  hintText: 'Email or phone for follow-up',
                ),
                textInputAction: StacTextInputAction.next,
                maxLines: 1,
              ),
              StacSizedBox(height: 16),
              StacTextFormField(
                id: 'feedback_message',
                decoration: const StacInputDecoration(
                  labelText: 'What should improve?',
                  hintText:
                      'Share at least 12 characters so the host team can act.',
                ),
                textInputAction: StacTextInputAction.done,
                minLines: 4,
                maxLines: 6,
                validatorRules: const [
                  StacFormFieldValidator(
                    rule: r'^.{12,}$',
                    message: 'Please share at least 12 characters of feedback.',
                  ),
                ],
              ),
              StacSizedBox(height: 24),
              StacFilledButton(
                onPressed: const StacFormValidate(
                  isValid: StacMultiAction(
                    sync: true,
                    actions: [
                      StacAction(
                        jsonData: {
                          'actionType': 'hostAction',
                          'requestId': 'feedback-submit-track',
                          'action': 'trackEvent',
                          'payload': {
                            'name': 'feedback_form_submitted',
                            'properties': {
                              'source': 'feedback_form',
                              'flow': 'portable_feedback',
                            },
                          },
                        },
                      ),
                      StacSnackBar(
                        behavior: StacSnackBarBehavior.floating,
                        content: {
                          'type': 'text',
                          'data':
                              'Feedback validated locally. Opening host follow-up.',
                        },
                      ),
                      StacAction(
                        jsonData: {
                          'actionType': 'hostAction',
                          'requestId': 'feedback-open-follow-up',
                          'action': 'openNativeScreen',
                          'payload': {
                            'route': 'feedback_follow_up',
                            'args': {
                              'source': 'feedback_form',
                              'channel': 'mini_program',
                            },
                            'expectResult': true,
                          },
                        },
                      ),
                    ],
                  ),
                  isNotValid: StacSnackBar(
                    behavior: StacSnackBarBehavior.floating,
                    content: {
                      'type': 'text',
                      'data':
                          'Please complete the required feedback message first.',
                    },
                  ),
                ),
                child: StacText(data: 'Validate and continue'),
              ),
              StacSizedBox(height: 12),
              StacOutlinedButton(
                onPressed: const StacAction(
                  jsonData: {
                    'actionType': 'hostAction',
                    'requestId': 'feedback-track-open',
                    'action': 'trackEvent',
                    'payload': {
                      'name': 'feedback_form_opened',
                      'properties': {
                        'source': 'feedback_form',
                        'surface': 'feedback_form',
                      },
                    },
                  },
                ),
                child: StacText(data: 'Track feedback view'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

StacWidget _topicChip(String label) {
  return StacContainer(
    padding: StacEdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: StacBoxDecoration(
      color: '#F8FAFC',
      borderRadius: StacBorderRadius.all(999),
    ),
    child: StacText(
      data: label,
      style: StacCustomTextStyle(
        fontSize: 14,
        fontWeight: StacFontWeight.w500,
        color: '#334155',
      ),
    ),
  );
}
