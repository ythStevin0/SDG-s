import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/models.dart';
import '../core/theme.dart';

class PriceForecastChart extends StatelessWidget {
  final List<PricePoint> series;
  final ForecastOutput forecast;
  final int? breakEvenPerKg;

  const PriceForecastChart({
    super.key,
    required this.series,
    required this.forecast,
    this.breakEvenPerKg,
  });

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final recent = series.length > 26 ? series.sublist(series.length - 26) : series;
    if (recent.isEmpty) {
      return const StatePanel(
        icon: Icons.show_chart_rounded,
        title: 'Riwayat harga belum tersedia',
        message: 'Pilih komoditas lain atau muat ulang data dari server.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StampBadge(
              label: 'Model: ${forecast.selectedModel}',
              icon: Icons.functions_rounded,
            ),
            StampBadge(
              label: 'Galat Backtest (MAPE): ${forecast.mapePct}%',
              icon: Icons.fact_check_outlined,
            ),
            StampBadge(
              label: '${forecast.dataPointsCount} minggu riwayat',
              icon: Icons.calendar_today_outlined,
            ),
            if (forecast.lowConfidence)
              const StampBadge(
                label: 'Riwayat pendek (<26 titik)',
                tone: StampTone.warn,
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 216,
          width: double.infinity,
          child: CustomPaint(
            painter: _PriceChartPainter(
              recent: recent,
              predictions: forecast.predictions,
              palette: p,
              breakEvenPerKg: breakEvenPerKg,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _legendItem(p.primary, 'Harga historis mingguan', p.inkMuted),
            _legendItem(p.harvestGold, 'Proyeksi 4, 8, dan 12 minggu', p.inkMuted),
            _legendItem(p.harvestGold.withValues(alpha: 0.25), 'Rentang kemungkinan 80%', p.inkMuted),
            if (breakEvenPerKg != null)
              _legendItem(p.dangerInk, 'Garis titik impas (Rp${formatIntId(breakEvenPerKg!)}/kg)',
                  p.inkMuted),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Perkiraan dihitung dari deret waktu historis dan bukan jaminan harga pasar.',
          style: TextStyle(fontSize: 12, color: p.inkMuted),
        ),
      ],
    );
  }

  Widget _legendItem(Color swatch, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  final List<PricePoint> recent;
  final List<HorizonPrediction> predictions;
  final SimpanJualPalette palette;
  final int? breakEvenPerKg;

  _PriceChartPainter({
    required this.recent,
    required this.predictions,
    required this.palette,
    this.breakEvenPerKg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 62.0;
    const rightPad = 14.0;
    const topPad = 12.0;
    const bottomPad = 26.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (chartW <= 20 || chartH <= 20) return;

    double minP = recent.first.hargaPerKg.toDouble();
    double maxP = minP;
    for (final pt in recent) {
      minP = math.min(minP, pt.hargaPerKg.toDouble());
      maxP = math.max(maxP, pt.hargaPerKg.toDouble());
    }
    for (final pr in predictions) {
      minP = math.min(minP, pr.priceLow);
      maxP = math.max(maxP, pr.priceHigh);
    }
    if (breakEvenPerKg != null) {
      minP = math.min(minP, breakEvenPerKg!.toDouble());
      maxP = math.max(maxP, breakEvenPerKg!.toDouble());
    }
    final padRange = math.max(200.0, (maxP - minP) * 0.14);
    minP = math.max(0, minP - padRange);
    maxP = maxP + padRange;

    final totalWeeks = (recent.length - 1) + 12;
    double xAt(double step) => leftPad + (step / totalWeeks) * chartW;
    double yAt(double price) => topPad + (1.0 - (price - minP) / (maxP - minP)) * chartH;

    final gridPaint = Paint()
      ..color = palette.borderSubtle
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final val = minP + ((maxP - minP) * i / 3.0);
      final y = yAt(val);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Rp${formatIntId(val)}',
          style: TextStyle(
            fontSize: 10.5,
            color: palette.inkMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    if (breakEvenPerKg != null) {
      final by = yAt(breakEvenPerKg!.toDouble());
      final bePaint = Paint()
        ..color = palette.dangerInk
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(leftPad, by), Offset(size.width - rightPad, by), bePaint);
    }

    final lastIdx = (recent.length - 1).toDouble();
    final lastPrice = recent.last.hargaPerKg.toDouble();

    if (predictions.isNotEmpty) {
      final bandPath = Path()..moveTo(xAt(lastIdx), yAt(lastPrice));
      for (final pr in predictions) {
        bandPath.lineTo(xAt(lastIdx + pr.horizonWeeks), yAt(pr.priceHigh));
      }
      for (final pr in predictions.reversed) {
        bandPath.lineTo(xAt(lastIdx + pr.horizonWeeks), yAt(pr.priceLow));
      }
      bandPath.close();
      final bandPaint = Paint()
        ..color = palette.harvestGold.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bandPath, bandPaint);
    }

    final histPath = Path();
    for (var i = 0; i < recent.length; i++) {
      final pt = Offset(xAt(i.toDouble()), yAt(recent[i].hargaPerKg.toDouble()));
      if (i == 0) {
        histPath.moveTo(pt.dx, pt.dy);
      } else {
        histPath.lineTo(pt.dx, pt.dy);
      }
    }
    final histPaint = Paint()
      ..color = palette.primary
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(histPath, histPaint);

    if (predictions.isNotEmpty) {
      final predPath = Path()..moveTo(xAt(lastIdx), yAt(lastPrice));
      final dotPaint = Paint()..color = palette.harvestGold;
      for (final pr in predictions) {
        final px = xAt(lastIdx + pr.horizonWeeks);
        final py = yAt(pr.pricePoint);
        predPath.lineTo(px, py);
        canvas.drawCircle(Offset(px, py), 4.4, dotPaint);

        final lbl = TextPainter(
          text: TextSpan(
            text: '+${pr.horizonWeeks}m',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        lbl.paint(canvas, Offset(px - lbl.width / 2, size.height - bottomPad + 6));
      }
      final predPaint = Paint()
        ..color = palette.harvestGold
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(predPath, predPaint);
    }

    final nowTp = TextPainter(
      text: TextSpan(
        text: 'Kini',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: palette.primary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nowTp.paint(canvas, Offset(xAt(lastIdx) - nowTp.width / 2, size.height - bottomPad + 6));
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) =>
      oldDelegate.recent != recent ||
      oldDelegate.predictions != predictions ||
      oldDelegate.palette != palette ||
      oldDelegate.breakEvenPerKg != breakEvenPerKg;
}
