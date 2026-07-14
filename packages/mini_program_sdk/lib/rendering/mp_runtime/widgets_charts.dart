part of '../mp_screen_renderer.dart';

class _MpLineChart extends StatelessWidget {
  const _MpLineChart({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final source = bindings.resolveStringValue(_string(node, 'source'));
    final points = _chartPoints(source);
    if (points.length < 2) {
      final empty = node.props['empty'] as _MpNode?;
      return empty == null
          ? const SizedBox.shrink()
          : _MpNodeView(node: empty, bindings: bindings);
    }

    final color = _mpColor(
      node.props['color'] as String?,
      fallback: const Color(0xFFF4C430),
    );
    final unit = node.props['unit'] as String? ?? '';
    final values = points.map((point) => point.value).toList(growable: false);
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final latest = values.last;
    final summary = <String>[
      if ((node.props['semanticLabel'] as String?) case final label?) label,
      '${points.length} points',
      'minimum ${_chartNumber(minimum)}$unit',
      'maximum ${_chartNumber(maximum)}$unit',
      'latest ${_chartNumber(latest)}$unit',
    ].join(', ');
    final labelInterval = math.max(1, (points.length / 8).ceil());

    return Semantics(
      label: summary,
      child: SizedBox(
        height: _double(node, 'height', fallback: 220),
        child: LineChart(
          LineChartData(
            minY: (node.props['minY'] as num?)?.toDouble(),
            maxY: (node.props['maxY'] as num?)?.toDouble(),
            gridData: FlGridData(show: _bool(node, 'showGrid')),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 42),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: labelInterval.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        points[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map(
                      (spot) => LineTooltipItem(
                        '${points[spot.x.round()].label}\n${_chartNumber(spot.y)}$unit',
                        const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: <FlSpot>[
                  for (var index = 0; index < points.length; index += 1)
                    FlSpot(index.toDouble(), points[index].value),
                ],
                isCurved: _bool(node, 'curved'),
                color: color,
                barWidth: _double(node, 'strokeWidth', fallback: 3),
                dotData: FlDotData(show: _bool(node, 'showPoints')),
                belowBarData: BarAreaData(
                  show: _bool(node, 'showArea'),
                  color: color.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 180),
        ),
      ),
    );
  }

  List<_MpChartPoint> _chartPoints(Object? source) {
    if (source is! List) {
      return const <_MpChartPoint>[];
    }
    final maxPoints = _int(node, 'maxPoints', fallback: 200);
    final valueField = _string(node, 'valueField');
    final labelField = node.props['labelField'] as String?;
    final points = <_MpChartPoint>[];
    final sourceLimit = math.min(source.length, maxPoints);
    for (var index = 0; index < sourceLimit; index += 1) {
      final item = source[index];
      if (item is! Map) {
        continue;
      }
      final value = _readPath(item, valueField);
      if (value is! num || !value.isFinite) {
        continue;
      }
      final rawLabel = labelField == null ? null : _readPath(item, labelField);
      points.add(
        _MpChartPoint(
          value: value.toDouble(),
          label: rawLabel?.toString() ?? '${index + 1}',
        ),
      );
    }
    return points;
  }
}

class _MpChartPoint {
  const _MpChartPoint({required this.value, required this.label});

  final double value;
  final String label;
}

String _chartNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
