import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/models.dart';

class PriceForecastChart extends StatelessWidget {
  final List<PricePoint> series;
  final ForecastOutput forecast;

  const PriceForecastChart({
    super.key,
    required this.series,
    required this.forecast,
  });

  @override
  Widget build(BuildContext context) {
    final recent = series.length > 26 ? series.sublist(series.length - 26) : series;
    if (recent.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('Data harga belum tersedia')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _badge(Icons.analytics_outlined, 'Model: ${forecast.selectedModel}',
                Colors.teal.shade800, Colors.teal.shade50),
            _badge(Icons.verified_outlined, 'MAPE Backtest: ${forecast.mapePct}%',
                Colors.indigo.shade800, Colors.indigo.shade50),
            _badge(Icons.timeline, '${forecast.dataPointsCount} minggu data',
                const Color(0xFF334155), Colors.grey.shade100),
            if (forecast.lowConfidence)
              _badge(Icons.warning_amber_rounded, 'Keyakinan rendah (<26 titik)',
                  Colors.amber.shade900, Colors.amber.shade50),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          width: double.infinity,
          child: CustomPaint(
            painter: _PriceChartPainter(recent: recent, predictions: forecast.predictions),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _legendDot(const Color(0xFF065F46), 'Historis Mingguan'),
            _legendDot(const Color(0xFFD97706), 'Proyeksi 4/8/12 Minggu'),
            _legendDot(const Color(0xFFFDE68A), 'Pita Ketidakpastian 80%'),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Catatan: Prediksi bersifat perkiraan statistik transparan, bukan jaminan harga pasar.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
      ],
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  final List<PricePoint> recent;
  final List<HorizonPrediction> predictions;

  _PriceChartPainter({required this.recent, required this.predictions});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 56.0;
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
    final padRange = math.max(200.0, (maxP - minP) * 0.14);
    minP = math.max(0, minP - padRange);
    maxP = maxP + padRange;

    final totalWeeks = (recent.length - 1) + 12;
    double xAt(double step) => leftPad + (step / totalWeeks) * chartW;
    double yAt(double price) => topPad + (1.0 - (price - minP) / (maxP - minP)) * chartH;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final val = minP + ((maxP - minP) * i / 3.0);
      final y = yAt(val);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Rp${formatIntId(val)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    final lastIdx = (recent.length - 1).toDouble();
    final lastPrice = recent.last.hargaPerKg.toDouble();

    // Gambar pita ketidakpastian 80%
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
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bandPath, bandPaint);
    }

    // Garis historis
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
      ..color = const Color(0xFF065F46)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(histPath, histPaint);

    // Garis proyeksi & titik horizon 4/8/12 minggu
    if (predictions.isNotEmpty) {
      final predPath = Path()..moveTo(xAt(lastIdx), yAt(lastPrice));
      final dotPaint = Paint()..color = const Color(0xFFD97706);
      for (final pr in predictions) {
        final px = xAt(lastIdx + pr.horizonWeeks);
        final py = yAt(pr.pricePoint);
        predPath.lineTo(px, py);
        canvas.drawCircle(Offset(px, py), 4.2, dotPaint);

        final lbl = TextPainter(
          text: TextSpan(
            text: '+${pr.horizonWeeks}m',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        lbl.paint(canvas, Offset(px - lbl.width / 2, size.height - bottomPad + 6));
      }
      final predPaint = Paint()
        ..color = const Color(0xFFD97706)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(predPath, predPaint);
    }

    // Label kini
    final nowTp = TextPainter(
      text: const TextSpan(
        text: 'Kini',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nowTp.paint(canvas, Offset(xAt(lastIdx) - nowTp.width / 2, size.height - bottomPad + 6));
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) =>
      oldDelegate.recent != recent || oldDelegate.predictions != predictions;
}
