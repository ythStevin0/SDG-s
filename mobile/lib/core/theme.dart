import 'package:flutter/material.dart';

class SimpanJualPalette extends ThemeExtension<SimpanJualPalette> {
  final Color frameBg;
  final Color stageLeft;
  final Color stageMid;
  final Color stageRight;
  final Color archSage;
  final Color sagePanel;
  final Color harvestGold;
  final Color goldTextOnDark;
  final Color onGold;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderSubtle;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color onPrimary;
  final Color okBg;
  final Color okInk;
  final Color warnBg;
  final Color warnInk;
  final Color dangerBg;
  final Color dangerInk;

  const SimpanJualPalette({
    required this.frameBg,
    required this.stageLeft,
    required this.stageMid,
    required this.stageRight,
    required this.archSage,
    required this.sagePanel,
    required this.harvestGold,
    required this.goldTextOnDark,
    required this.onGold,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderSubtle,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.okBg,
    required this.okInk,
    required this.warnBg,
    required this.warnInk,
    required this.dangerBg,
    required this.dangerInk,
  });

  static const light = SimpanJualPalette(
    frameBg: Color(0xFF193226),
    stageLeft: Color(0xFF183D31),
    stageMid: Color(0xFF265340),
    stageRight: Color(0xFF7BA866),
    archSage: Color(0xFFCEDFB5),
    sagePanel: Color(0xFF84AE6B),
    harvestGold: Color(0xFFE5AF42),
    goldTextOnDark: Color(0xFFF4C95D),
    onGold: Color(0xFF193226),
    bg: Color(0xFFF3F7F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE5EFE0),
    border: Color(0xFF647D6D),
    borderSubtle: Color(0xFFC8D8C4),
    ink: Color(0xFF162A20),
    inkMuted: Color(0xFF395244),
    primary: Color(0xFF183D31),
    onPrimary: Color(0xFFFFFFFF),
    okBg: Color(0xFFDCFCE7),
    okInk: Color(0xFF14532D),
    warnBg: Color(0xFFFEF3C7),
    warnInk: Color(0xFF78350F),
    dangerBg: Color(0xFFFEE2E2),
    dangerInk: Color(0xFF7F1D1D),
  );

  static const dark = SimpanJualPalette(
    frameBg: Color(0xFF0E1E16),
    stageLeft: Color(0xFF143328),
    stageMid: Color(0xFF224938),
    stageRight: Color(0xFF5D8A52),
    archSage: Color(0xFFCEDFB5),
    sagePanel: Color(0xFF84AE6B),
    harvestGold: Color(0xFFE5AF42),
    goldTextOnDark: Color(0xFFF4C95D),
    onGold: Color(0xFF193226),
    bg: Color(0xFF13261D),
    surface: Color(0xFF1B3529),
    surfaceAlt: Color(0xFF234334),
    border: Color(0xFF6E917D),
    borderSubtle: Color(0xFF2F5342),
    ink: Color(0xFFEDF5EE),
    inkMuted: Color(0xFFB9CFC0),
    primary: Color(0xFFEBB844),
    onPrimary: Color(0xFF193226),
    okBg: Color(0xFF064E3B),
    okInk: Color(0xFFD1FAE5),
    warnBg: Color(0xFF78350F),
    warnInk: Color(0xFFFEF3C7),
    dangerBg: Color(0xFF7F1D1D),
    dangerInk: Color(0xFFFEE2E2),
  );

  static SimpanJualPalette of(BuildContext context) {
    return Theme.of(context).extension<SimpanJualPalette>() ?? light;
  }

  @override
  SimpanJualPalette copyWith({Color? bg}) => this;

  @override
  SimpanJualPalette lerp(ThemeExtension<SimpanJualPalette>? other, double t) {
    if (other is! SimpanJualPalette) return this;
    return t < 0.5 ? this : other;
  }
}

ThemeData buildSimpanJualTheme({required bool isDark, required bool fieldMode}) {
  final p = isDark ? SimpanJualPalette.dark : SimpanJualPalette.light;
  final bw = fieldMode ? 1.6 : 1.15;

  final scheme = ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.harvestGold,
    onSecondary: p.onGold,
    error: p.dangerInk,
    onError: p.dangerBg,
    surface: p.surface,
    onSurface: p.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    dividerColor: p.borderSubtle,
    focusColor: p.harvestGold.withValues(alpha: 0.28),
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.frameBg,
      foregroundColor: const Color(0xFFF3F7F0),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(14),
        ),
        side: BorderSide(color: p.border, width: bw),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      labelStyle: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: p.inkMuted.withValues(alpha: 0.85)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.border, width: bw),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.harvestGold, width: 2.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.dangerInk, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: p.border, width: bw),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceAlt,
      labelStyle: TextStyle(color: p.ink, fontSize: 12, fontWeight: FontWeight.w700),
      side: BorderSide(color: p.border, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.inkMuted,
      indicatorColor: p.harvestGold,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.frameBg,
      indicatorColor: p.harvestGold,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? p.onGold : const Color(0xFFC2D6C4),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? p.goldTextOnDark : const Color(0xFFC2D6C4),
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        );
      }),
    ),
  );
}

// Logo Konsep 1 Pilihan Pemilik: Atap Lumbung + Jarum Timbangan + Bulir Emas
class SimpanJualBrand extends StatelessWidget {
  final bool lightOnDark;
  final bool compact;

  const SimpanJualBrand({
    super.key,
    this.lightOnDark = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final fg = lightOnDark ? const Color(0xFFFFFFFF) : p.ink;
    final grain = p.harvestGold;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(compact ? 30 : 34, compact ? 30 : 34),
          painter: _BarnScaleLogoPainter(primaryColor: fg, grainColor: grain),
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simpan',
              style: TextStyle(
                color: fg,
                fontSize: compact ? 13 : 14.5,
                fontWeight: FontWeight.w900,
                height: 1.02,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Jual',
              style: TextStyle(
                color: lightOnDark ? p.goldTextOnDark : p.inkMuted,
                fontSize: compact ? 13 : 14.5,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarnScaleLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color grainColor;

  const _BarnScaleLogoPainter({required this.primaryColor, required this.grainColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Siluet atap lumbung
    final roof = Path()
      ..moveTo(w * 0.10, h * 0.42)
      ..lineTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.90, h * 0.42);
    canvas.drawPath(roof, stroke);

    // Tiang dinding lumbung kiri & kanan
    canvas.drawLine(Offset(w * 0.20, h * 0.40), Offset(w * 0.20, h * 0.86), stroke);
    canvas.drawLine(Offset(w * 0.80, h * 0.40), Offset(w * 0.80, h * 0.86), stroke);
    canvas.drawLine(Offset(w * 0.14, h * 0.86), Offset(w * 0.86, h * 0.86), stroke);

    // Jarum & palang timbangan koperasi di dalam lumbung
    final beamPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.50, h * 0.26), Offset(w * 0.50, h * 0.54), beamPaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.48), Offset(w * 0.70, h * 0.48), beamPaint);

    // Bulir gabah emas sebagai titik tumpu keseimbangan
    final grainPath = Path()
      ..moveTo(w * 0.50, h * 0.52)
      ..quadraticBezierTo(w * 0.65, h * 0.65, w * 0.50, h * 0.80)
      ..quadraticBezierTo(w * 0.35, h * 0.65, w * 0.50, h * 0.52)
      ..close();
    canvas.drawPath(grainPath, Paint()..color = grainColor);
  }

  @override
  bool shouldRepaint(covariant _BarnScaleLogoPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor || oldDelegate.grainColor != grainColor;
}

// Tombol Kapsul Belah Lingkaran Panah Emas sesuai foto referensi ("Shop Now (->)")
class SplitGoldCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool darkBackground;

  const SplitGoldCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final bg = darkBackground ? const Color(0xFF1A3F32) : p.frameBg;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          focusColor: p.harvestGold.withValues(alpha: 0.3),
          child: Ink(
            height: 50,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.harvestGold, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 22, right: 16),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: p.harvestGold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: p.onGold,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum StampTone { ok, warn, danger, neutral }

class StampBadge extends StatelessWidget {
  final String label;
  final StampTone tone;
  final IconData? icon;

  const StampBadge({
    super.key,
    required this.label,
    this.tone = StampTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final (bg, fg, defaultIcon) = switch (tone) {
      StampTone.ok => (p.okBg, p.okInk, Icons.check_circle_outline_rounded),
      StampTone.warn => (p.warnBg, p.warnInk, Icons.error_outline_rounded),
      StampTone.danger => (p.dangerBg, p.dangerInk, Icons.cancel_outlined),
      StampTone.neutral => (p.surfaceAlt, p.ink, Icons.verified_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: fg, width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LedgerRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  const LedgerRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize ? p.ink : p.inkMuted,
                fontSize: emphasize ? 14 : 13,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? p.ink,
              fontSize: emphasize ? 15.5 : 13.5,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final bool isLoading;

  const StatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    return Card(
      color: isError ? p.dangerBg : p.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: p.primary),
                  )
                else
                  Icon(icon, color: isError ? p.dangerInk : p.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: isError ? p.dangerInk : p.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                color: isError ? p.dangerInk : p.inkMuted,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Grid responsif 3 rentang layar: 1 kolom (<640px), 2 kolom (640-1023px), 3 kolom (>=1024px)
class ResponsiveThreeStageGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  final double spacing;

  const ResponsiveThreeStageGrid({
    super.key,
    required this.children,
    this.maxColumns = 3,
    this.spacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols = 1;
        if (w >= 960) {
          cols = maxColumns;
        } else if (w >= 600) {
          cols = maxColumns >= 2 ? 2 : 1;
        }
        if (cols <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.skip(i).take(cols).toList();
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) SizedBox(width: spacing),
                  Expanded(
                    child: c < slice.length ? slice[c] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: spacing),
              rows[r],
            ],
          ],
        );
      },
    );
  }
}
