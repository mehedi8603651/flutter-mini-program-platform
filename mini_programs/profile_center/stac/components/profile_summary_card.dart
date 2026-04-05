import 'package:stac_core/stac_core.dart';

StacWidget profileSummaryCard() {
  return StacContainer(
    padding: StacEdgeInsets.all(16),
    decoration: StacBoxDecoration(
      color: '#FFFFFF',
      borderRadius: StacBorderRadius.all(20),
    ),
    child: StacColumn(
      crossAxisAlignment: StacCrossAxisAlignment.start,
      children: [
        StacText(
          data: 'Preview user',
          style: StacCustomTextStyle(
            fontSize: 16,
            fontWeight: StacFontWeight.w600,
          ),
        ),
        StacSizedBox(height: 8),
        StacText(data: 'Name: Guest User'),
        StacText(data: 'Tier: Super App Preview'),
      ],
    ),
  );
}
