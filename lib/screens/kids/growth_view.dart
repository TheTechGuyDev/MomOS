import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/kids_service.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import 'log_sheets.dart';

class GrowthView extends StatefulWidget {
  final Child child;
  const GrowthView({super.key, required this.child});
  @override
  State<GrowthView> createState() => _GrowthViewState();
}

class _GrowthViewState extends State<GrowthView> {
  List<KidLog> _logs = [];
  bool _loading = true;
  String _metric = 'weight_kg';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GrowthView old) {
    super.didUpdateWidget(old);
    if (old.child.id != widget.child.id) _load();
  }

  Future<void> _load() async {
    try {
      final l = await KidsService.logs(widget.child.id, kind: 'growth');
      if (mounted) {
        setState(() {
          _logs = l;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final points = _logs
        .where((l) => l.data[_metric] != null)
        .map((l) => (l.startedAt, (l.data[_metric] as num).toDouble()))
        .toList()
        .reversed
        .toList();
    final unit = _metric == 'weight_kg' ? 'kg' : 'cm';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          FilledButton.icon(
            onPressed: () async {
              if (await showGrowthSheet(context, widget.child) == true) _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add measurement'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'weight_kg', label: Text('Weight')),
              ButtonSegment(value: 'height_cm', label: Text('Height')),
              ButtonSegment(value: 'head_cm', label: Text('Head')),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
          const SizedBox(height: 14),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: points.length < 2
                ? Center(
                    child: Text(
                      points.isEmpty ? 'No measurements yet' : 'Add one more to see the chart',
                      style: t.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  )
                : CustomPaint(painter: _LineChart(points, unit), size: Size.infinite),
          ),
          if (points.length >= 2) ...[
            const SizedBox(height: 10),
            Text(
              'Change: ${(points.last.$2 - points.first.$2) >= 0 ? '+' : ''}${(points.last.$2 - points.first.$2).toStringAsFixed(1)} $unit since ${shortDate(points.first.$1)}',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 18),
          Text('History', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ..._logs.map((l) => Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Text('📏', style: TextStyle(fontSize: 24)),
                  title: Text(l.title.replaceFirst('Growth · ', ''), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(shortDate(l.startedAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                    onPressed: () async {
                      await KidsService.deleteLog(l.id);
                      _load();
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _LineChart extends CustomPainter {
  final List<(DateTime, double)> pts;
  final String unit;
  _LineChart(this.pts, this.unit);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, bottom = 22.0;
    final w = size.width - left, h = size.height - bottom;
    final minV = pts.map((p) => p.$2).reduce(min), maxV = pts.map((p) => p.$2).reduce(max);
    final pad = max((maxV - minV) * 0.15, 0.5);
    final lo = minV - pad, hi = maxV + pad;
    final t0 = pts.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = max(pts.last.$1.millisecondsSinceEpoch.toDouble(), t0 + 1);

    Offset at((DateTime, double) p) => Offset(
          left + (p.$1.millisecondsSinceEpoch - t0) / (t1 - t0) * w,
          h - (p.$2 - lo) / (hi - lo) * h,
        );

    final grid = Paint()..color = const Color(0xFFF0E6E9)..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 3; i++) {
      final y = h * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      tp.text = TextSpan(
        text: (hi - (hi - lo) * i / 3).toStringAsFixed(1),
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y - 6));
    }

    final path = Path()..moveTo(at(pts.first).dx, at(pts.first).dy);
    for (final p in pts.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    final fill = Path.from(path)
      ..lineTo(at(pts.last).dx, h)
      ..lineTo(at(pts.first).dx, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.25), AppColors.primary.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in pts) {
      canvas.drawCircle(at(p), 5, Paint()..color = Colors.white);
      canvas.drawCircle(at(p), 3.5, Paint()..color = AppColors.primary);
    }
    for (final p in [pts.first, pts.last]) {
      tp.text = TextSpan(
        text: '${p.$1.day}/${p.$1.month}',
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      );
      tp.layout();
      tp.paint(canvas, Offset((at(p).dx - tp.width / 2).clamp(left, size.width - tp.width), h + 6));
    }
  }

  @override
  bool shouldRepaint(_LineChart old) => old.pts != pts;
}
