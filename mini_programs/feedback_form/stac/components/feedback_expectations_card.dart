import 'package:stac_core/stac_core.dart';

StacWidget feedbackExpectationsCard() {
  return StacContainer(
    padding: StacEdgeInsets.all(18),
    decoration: StacBoxDecoration(
      color: '#FFFFFF',
      borderRadius: StacBorderRadius.all(20),
    ),
    child: StacColumn(
      crossAxisAlignment: StacCrossAxisAlignment.start,
      children: [
        StacText(
          data: 'What this portable flow proves',
          style: StacCustomTextStyle(
            fontSize: 16,
            fontWeight: StacFontWeight.w700,
            color: '#1E293B',
          ),
        ),
        StacSizedBox(height: 10),
        StacText(data: '1. Local form validation runs in portable UI.'),
        StacText(
          data:
              '2. Secure feedback submission stays behind the shared host bridge.',
        ),
        StacText(
          data:
              '3. Analytics stays behind the shared host bridge.',
        ),
        StacText(
          data:
              '4. The same route alias opens different native follow-up pages '
              'in each host app.',
        ),
      ],
    ),
  );
}
