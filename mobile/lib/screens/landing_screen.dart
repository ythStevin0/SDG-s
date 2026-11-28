import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/formatters.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/server_config_dialog.dart';

class LandingScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onOpenAuth;

  const LandingScreen({
    super.key,
    required this.appState,
    required this.onOpenAuth,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _simulatorKey = GlobalKey();
  final GlobalKey _actorsKey = GlobalKey();

  int _heroSlide = 0;
  String _selectedKode = 'jagung';
  double _qtyKg = 5000;
  double _kadarAir = 18;
  bool _useSrgLoan = true;
  final _panjarCtrl = TextEditingController(text: '3800');

  bool _loadingImpact = true;
  String? _impactError;
  Map<String, dynamic>? _impact;
  DecisionResult? _simDecision;
  PanjarResult? _simPanjar;
  int _latestPrice = 5200;

  static const _slides = [
    (
      eyebrow: 'KOMODITAS PASCAPANEN',
      headline: 'PANEN RAYA',
      subtitlePlain: 'Hitungan jujur ',
      subtitleBold1: 'tahan gudang SRG',
      subtitleMid: ' atau ',
      subtitleBold2: 'jual panen segera',
      ctaLabel: 'Hitung Titik Impas',
      kode: 'jagung',
    ),
    (
      eyebrow: 'KONVERSI KADAR AIR GKP KE GKG',
      headline: 'PADI GABAH',
      subtitlePlain: 'Potong susut jemur ',
      subtitleBold1: 'kadar air 22% ke 14%',
      subtitleMid: ' sebelum adu dengan ',
      subtitleBold2: 'panjar tengkulak',
      ctaLabel: 'Uji Simulasi Gabah',
      kode: 'gabah',
    ),
    (
      eyebrow: 'LOT KOLEKTIF & PEMBELI SIAGA',
      headline: 'LUMBUNG SRG',
      subtitlePlain: 'Gabung kode poktan ',
      subtitleBold1: 'TANIJAYA 10 ton',
      subtitleMid: ' dan kunci kuota ',
      subtitleBold2: 'Janji Beli SPPG',
      ctaLabel: 'Masuk 5 Akun Demo',
      kode: 'jagung',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _panjarCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingImpact = true;
      _impactError = null;
    });
    try {
      final imp = await widget.appState.api.fetchImpact();
      await _recalculateLocal();
      if (mounted) {
        setState(() {
          _impact = imp;
          _loadingImpact = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _impactError = e.toString().replaceFirst('Exception: ', '');
          _loadingImpact = false;
        });
      }
    }
  }

  Future<void> _recalculateLocal() async {
    final pr = await widget.appState.api.fetchPrices(_selectedKode);
    final panjarPerKg = double.tryParse(_panjarCtrl.text.replaceAll('.', '')) ?? 3800;
    final dec = SimpanJualEngine.evaluateHoldVsSell(
      qtyKg: _qtyKg,
      kadarAirAktual: _kadarAir,
      kadarAirAmbang: pr.commodity.params.kadarAirMaksPct,
      biayaPengeringanPerKg: pr.commodity.params.biayaPengeringanPerKg,
      p0Dry: pr.latestPrice.toDouble(),
      predictions: pr.forecast.predictions,
      tarifSewaPerKgHari: 2.5,
      biayaAngkutPerKg: 20,
      biayaTetap: 100000,
      susutPerBulan: pr.commodity.params.susutPerBulan,
      rasioPinjaman: _useSrgLoan ? 0.70 : 0.0,
      bungaTahunan: 0.06,
    );
    final pj = SimpanJualEngine.evaluatePanjar(
      mode: 'per_kg',
      hargaPanjarPerKg: panjarPerKg > 0 ? panjarPerKg : 3800,
      qtyKg: _qtyKg,
      p0Actual: pr.latestPrice.toDouble(),
      pendapatanTahanRp: dec.best.pendapatanTahan.toDouble(),
      pinjamanSrgRp: dec.pinjamanAwal.toDouble(),
    );
    if (mounted) {
      setState(() {
        _latestPrice = pr.latestPrice;
        _simDecision = dec;
        _simPanjar = pj;
      });
    }
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openQuickMenuSheet() {
    final p = SimpanJualPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Navigasi Cepat SimpanJual',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.calculate_outlined, color: p.primary),
                title: const Text('Kalkulator Tahan vs Panjar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToSection(_simulatorKey);
                },
              ),
              ListTile(
                leading: Icon(Icons.groups_outlined, color: p.primary),
                title: const Text('Alur 4 Peran Pascapanen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToSection(_actorsKey);
                },
              ),
              ListTile(
                leading: Icon(Icons.dns_outlined, color: p.primary),
                title: const Text('Atur Koneksi Server Go / Mode Offline'),
                onTap: () {
                  Navigator.pop(ctx);
                  showServerConfigDialog(context, widget.appState);
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onOpenAuth();
                },
                child: const Text('Masuk / Pilih 5 Akun Demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1024;
    final isTablet = w >= 640 && w < 1024;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Panggung Utama Editorial Botani penuh dari tepi ke tepi tanpa bingkai luar
              _buildBotanicalShowcaseStage(p, w, isDesktop: isDesktop, isTablet: isTablet),

              // Area Konten Bawah di atas permukaan bg mode Terang / Gelap
              Container(
                color: p.bg,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 36 : (isTablet ? 22 : 16),
                  vertical: isDesktop ? 36 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          key: _simulatorKey,
                          child: _buildInteractiveSimulatorSection(p, isDesktop: isDesktop),
                        ),
                        SizedBox(height: isDesktop ? 32 : 22),
                        Container(
                          key: _actorsKey,
                          child: _buildFourActorsSection(p),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotanicalShowcaseStage(
    SimpanJualPalette p,
    double screenW, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    final slide = _slides[_heroSlide];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            p.stageLeft,
            p.stageMid,
            p.stageRight,
          ],
          stops: const [0.0, 0.50, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStageTopNavbar(p, isDesktop: isDesktop, isTablet: isTablet),
          if (isDesktop || isTablet)
            SizedBox(
              height: isDesktop ? 468 : 400,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: isDesktop ? 55 : 54,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 52 : 28,
                        isDesktop ? 48 : 30,
                        20,
                        24,
                      ),
                      child: _buildHeroCopyBlock(p, slide, isDesktop: isDesktop, isMobile: false),
                    ),
                  ),
                  Expanded(
                    flex: isDesktop ? 45 : 46,
                    child: _buildRightSageArchShowcase(p, isDesktop: isDesktop, isMobile: false),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: _buildHeroCopyBlock(p, slide, isDesktop: false, isMobile: true),
            ),
            SizedBox(
              height: 300,
              child: _buildRightSageArchShowcase(p, isDesktop: false, isMobile: true),
            ),
          ],
          _buildStageBottomStrip(p, isDesktop: isDesktop, isTablet: isTablet),
        ],
      ),
    );
  }

  Widget _buildStageTopNavbar(
    SimpanJualPalette p, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          SizedBox(width: isDesktop ? 44 : 18),
          const SimpanJualBrand(lightOnDark: true),
          if (isDesktop || isTablet) ...[
            SizedBox(width: isDesktop ? 56 : 24),
            _stageNavItem(
              label: 'Beranda',
              active: true,
              gold: p.harvestGold,
              goldText: p.goldTextOnDark,
              onTap: () {},
            ),
            _navDot(),
            _stageNavItem(
              label: 'Simulasi Impas',
              active: false,
              gold: p.harvestGold,
              goldText: p.goldTextOnDark,
              onTap: () => _scrollToSection(_simulatorKey),
            ),
            _navDot(),
            _stageNavItem(
              label: 'Panjar %',
              active: false,
              gold: p.harvestGold,
              goldText: p.goldTextOnDark,
              onTap: () => _scrollToSection(_actorsKey),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: widget.appState.darkMode ? 'Mode Terang' : 'Mode Rimbun Gelap',
            onPressed: widget.appState.toggleDarkMode,
            icon: Icon(
              widget.appState.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (isDesktop || isTablet)
            IconButton(
              tooltip: 'Masuk Akun Petani / Gudang / Pembeli',
              onPressed: widget.onOpenAuth,
              icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 21),
            ),
          const SizedBox(width: 4),
          // Kapsul Emas "5 Demo" dengan area sentuh minimal 44px (R-03)
          Semantics(
            button: true,
            label: 'Buka 5 akun demo siap pakai',
            child: InkWell(
              onTap: widget.onOpenAuth,
              borderRadius: BorderRadius.circular(999),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.harvestGold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '5 Demo',
                          style: TextStyle(
                            color: p.onGold,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.login_rounded, size: 15, color: p.onGold),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Blok sudut kanan atas hijau hutan gelap untuk menu cepat
          Semantics(
            button: true,
            label: 'Buka menu navigasi cepat',
            child: Material(
              color: const Color(0xFF284D38),
              child: InkWell(
                onTap: _openQuickMenuSheet,
                child: const SizedBox(
                  width: 68,
                  height: 68,
                  child: Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageNavItem({
    required String label,
    required bool active,
    required Color gold,
    required Color goldText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: active ? gold : Colors.transparent,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: active ? goldText : Colors.white,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _navDot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text('•', style: TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }

  Widget _buildHeroCopyBlock(
    SimpanJualPalette p,
    ({
      String eyebrow,
      String headline,
      String subtitlePlain,
      String subtitleBold1,
      String subtitleMid,
      String subtitleBold2,
      String ctaLabel,
      String kode,
    }) slide, {
    required bool isDesktop,
    required bool isMobile,
  }) {
    final headlineSize = isDesktop ? 76.0 : (isMobile ? 46.0 : 56.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          slide.eyebrow,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            slide.headline,
            style: TextStyle(
              color: Colors.white,
              fontSize: headlineSize,
              fontWeight: FontWeight.w900,
              height: 0.96,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: const Color(0xFFEAF4EC),
              fontSize: isDesktop ? 16 : 14.5,
              height: 1.45,
            ),
            children: [
              TextSpan(text: slide.subtitlePlain),
              TextSpan(
                text: slide.subtitleBold1,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
              ),
              TextSpan(text: slide.subtitleMid),
              TextSpan(
                text: slide.subtitleBold2,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SplitGoldCtaButton(
              label: slide.ctaLabel,
              onPressed: () {
                if (_heroSlide == 2) {
                  widget.onOpenAuth();
                } else {
                  setState(() => _selectedKode = slide.kode);
                  _recalculateLocal();
                  _scrollToSection(_simulatorKey);
                }
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: p.goldTextOnDark),
              onPressed: widget.onOpenAuth,
              child: const Text('Coba Akun Demo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightSageArchShowcase(
    SimpanJualPalette p, {
    required bool isDesktop,
    required bool isMobile,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Panel Lengkungan Sudut Kiri Atas (#CEDFB5 menyatu mulus dengan ilustrasi panen)
        Positioned.fill(
          top: isMobile ? 12 : 28,
          left: isMobile ? 16 : 10,
          child: Container(
            decoration: BoxDecoration(
              color: p.archSage,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isDesktop ? 88 : 52),
              ),
            ),
          ),
        ),
        // Ilustrasi Studio Batang Jagung Emas & Malai Padi
        Positioned.fill(
          left: isMobile ? 24 : 18,
          right: isMobile ? 48 : 56,
          bottom: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/hero_harvest.jpg',
              fit: BoxFit.contain,
              semanticLabel: 'Rumpun jagung emas dan malai padi siap panen',
            ),
          ),
        ),
        // Pemilih Slide Vertikal di Tepi Kanan (berfungsi nyata mengganti fokus komoditas)
        Positioned(
          right: isMobile ? 10 : 18,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_slides.length, (idx) {
                final active = idx == _heroSlide;
                return Semantics(
                  button: true,
                  selected: active,
                  label: 'Tampilkan panggung ${_slides[idx].headline}',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _heroSlide = idx;
                        _selectedKode = _slides[idx].kode;
                      });
                      _recalculateLocal();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        width: active ? 22 : 8,
                        height: active ? 22 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? Colors.transparent : p.frameBg.withValues(alpha: 0.65),
                          border: active ? Border.all(color: p.frameBg, width: 2) : null,
                        ),
                        child: active
                            ? Center(
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: p.frameBg,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageBottomStrip(
    SimpanJualPalette p, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    final tambahanRp = formatRupiah((_impact?['tambahanPendapatanRp'] as num? ?? 4250000));
    final terserapKg = formatKg((_impact?['stokTerserapKg'] as num? ?? 10000));
    final susutKg = formatKg((_impact?['susutDicegahKg'] as num? ?? 240));

    if (!isDesktop && !isTablet) {
      return Container(
        color: p.frameBg,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 92,
                  height: 76,
                  decoration: BoxDecoration(
                    color: p.harvestGold,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(26),
                      topRight: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/crop_cluster.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    semanticLabel: 'Ikatan malai padi dan tongkol jagung kering',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Simulasi dampak aktif: $tambahanRp pendapatan terlindungi dan $terserapKg terserap pembeli.',
                    style: const TextStyle(color: Color(0xFFF3F7F0), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Susut dicegah: $susutKg',
                  style: const TextStyle(
                    color: Color(0xFFC2D6C4),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    _circleQuickAction(
                      icon: Icons.volume_up_outlined,
                      tooltip: 'Bacakan ringkasan SimpanJual',
                      onTap: () => widget.appState.speakText(
                        'SimpanJual membantu petani menghitung titik impas simpan gudang S R G dibanding panjar tengkulak.',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _circleQuickAction(
                      icon: Icons.format_size_rounded,
                      tooltip: 'Perbesar huruf Mode Lapangan Aa+',
                      onTap: widget.appState.toggleFieldMode,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Tata pita bawah 4 bagian persis seperti foto referensi untuk Tablet & Desktop
    return SizedBox(
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tombol panah gulir ke kalkulator di kiri bawah
          Container(
            width: isDesktop ? 92 : 64,
            color: p.stageLeft,
            child: Center(
              child: IconButton(
                tooltip: 'Gulir ke Kalkulator Titik Impas',
                onPressed: () => _scrollToSection(_simulatorKey),
                icon: const Icon(Icons.south_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
          // 2. Kartu sudut kiri atas melengkung warna emas (#E5AF42) berisi hasil panen
          Container(
            width: isDesktop ? 196 : 144,
            decoration: BoxDecoration(
              color: p.harvestGold,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(36)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/crop_cluster.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              semanticLabel: 'Hasil panen gabah dan jagung kering',
            ),
          ),
          // 3. Dua kolom fakta dampak di atas hijau hutan gelap (#193226)
          Expanded(
            child: Container(
              color: p.frameBg,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pendapatan petani terlindungi: $tambahanRp',
                          style: const TextStyle(
                            color: Color(0xFFF3F7F0),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dihitung jujur sesudah susut kadar air & ongkos S-SRG 6%',
                          style: TextStyle(color: Color(0xFFC2D6C4), fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pasokan terserap: $terserapKg (Susut dicegah $susutKg)',
                          style: const TextStyle(
                            color: Color(0xFFF3F7F0),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loadingImpact
                              ? 'Memuat data simulasi...'
                              : (_impactError != null
                                  ? 'Mode simulasi mandiri aktif'
                                  : 'Terhubung ke Lot Poktan & Janji Beli daerah'),
                          style: const TextStyle(color: Color(0xFFC2D6C4), fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 4. Blok kanan bawah hijau daun berisi tombol bundar aksesibilitas lapangan
          Container(
            width: isDesktop ? 204 : 164,
            color: p.sagePanel,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleQuickAction(
                  icon: Icons.volume_up_outlined,
                  tooltip: 'Bacakan pengantar suara Bahasa Indonesia',
                  fgColor: p.onGold,
                  onTap: () => widget.appState.speakText(
                    'Selamat datang di SimpanJual. Hitung titik impas tahan panen atau coba lima akun demo.',
                  ),
                ),
                const SizedBox(width: 8),
                _circleQuickAction(
                  icon: Icons.format_size_rounded,
                  tooltip: 'Mode huruf besar lapangan Aa+',
                  fgColor: p.onGold,
                  onTap: widget.appState.toggleFieldMode,
                ),
                const SizedBox(width: 8),
                _circleQuickAction(
                  icon: Icons.dns_outlined,
                  tooltip: 'Pengaturan koneksi server',
                  fgColor: p.onGold,
                  filledWhite: true,
                  onTap: () => showServerConfigDialog(context, widget.appState),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleQuickAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color fgColor = Colors.white,
    bool filledWhite = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filledWhite ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: filledWhite ? Colors.white : fgColor,
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: fgColor, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveSimulatorSection(SimpanJualPalette p, {required bool isDesktop}) {
    final dec = _simDecision;
    final pj = _simPanjar;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 26 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kalkulator Cepat Tahan Gudang vs Panjar Tengkulak',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: p.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Harga acuan pasar kering saat ini: ${formatRupiah(_latestPrice)}/kg (Data ilustrasi Jawa Tengah)',
                        style: TextStyle(fontSize: 13, color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
                const StampBadge(label: 'TANPA LOGIN'),
              ],
            ),
            const Divider(height: 26),
            ResponsiveThreeStageGrid(
              maxColumns: 2,
              spacing: 22,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'jagung', label: Text('Jagung Pipil (KA ≤15%)')),
                        ButtonSegment(value: 'gabah', label: Text('Gabah GKG (KA ≤14%)')),
                      ],
                      selected: {_selectedKode},
                      onSelectionChanged: (s) {
                        setState(() => _selectedKode = s.first);
                        _recalculateLocal();
                      },
                    ),
                    const SizedBox(height: 14),
                    LedgerRow(label: 'Volume panen petani', value: formatKg(_qtyKg), emphasize: true),
                    Slider(
                      value: _qtyKg,
                      min: 500,
                      max: 15000,
                      divisions: 29,
                      onChanged: (v) {
                        setState(() => _qtyKg = v);
                        _recalculateLocal();
                      },
                    ),
                    LedgerRow(
                      label: 'Kadar air aktual saat panen',
                      value: '${_kadarAir.toStringAsFixed(1)}%',
                      emphasize: true,
                    ),
                    Slider(
                      value: _kadarAir,
                      min: 12,
                      max: 26,
                      divisions: 28,
                      onChanged: (v) {
                        setState(() => _kadarAir = v);
                        _recalculateLocal();
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _panjarCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tawaran panjar tengkulak (Rp/kg)',
                              hintText: 'Contoh: 3800',
                            ),
                            onSubmitted: (_) => _recalculateLocal(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _recalculateLocal,
                          child: const Text('Hitung'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Gunakan dana talangan subsidi S-SRG (bunga 6%/thn, plafon 70%)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink),
                      ),
                      value: _useSrgLoan,
                      onChanged: (v) {
                        setState(() => _useSrgLoan = v);
                        _recalculateLocal();
                      },
                    ),
                  ],
                ),
                if (dec != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border.all(color: p.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'REKAP KEPUTUSAN',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: p.inkMuted,
                              ),
                            ),
                            StampBadge(
                              label: dec.recommendation == 'JUAL'
                                  ? 'JUAL SEKARANG'
                                  : '${formatStatusLabel(dec.recommendation)} ${dec.bestHorizonWeeks} MINGGU',
                              tone: dec.recommendation == 'TAHAN'
                                  ? StampTone.ok
                                  : (dec.recommendation == 'TAHAN_BERISIKO'
                                      ? StampTone.warn
                                      : StampTone.danger),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LedgerRow(
                          label: 'Hasil jual langsung hari ini',
                          value: formatRupiah(dec.pendapatanJualSegera),
                        ),
                        if (dec.perluPengeringan)
                          LedgerRow(
                            label: 'Bobot kering siap simpan',
                            value: '${formatKg(dec.qtySiap)} (-${formatKg(dec.susutPengeringanKg)})',
                          ),
                        LedgerRow(
                          label: 'Total biaya jemur, sewa, angkut, & bunga',
                          value: formatRupiah(dec.best.totalBiayaSimpan),
                        ),
                        LedgerRow(
                          label: 'Titik impas harga simpan',
                          value: '${formatRupiah(dec.best.titikImpasPerKg)}/kg',
                          emphasize: true,
                        ),
                        LedgerRow(
                          label: 'Selisih bersih tahan vs jual segera',
                          value:
                              '${formatRupiah(dec.best.selisihRp, showPlus: true)} (${dec.best.selisihPct}%)',
                          emphasize: true,
                          valueColor: dec.best.selisihRp >= 0 ? p.okInk : p.dangerInk,
                        ),
                        if (pj != null) ...[
                          const Divider(height: 18),
                          LedgerRow(
                            label: 'Selisih diselamatkan dibanding panjar',
                            value: formatRupiah(pj.selisihTerhadapTahanRp, showPlus: true),
                            emphasize: true,
                            valueColor: p.okInk,
                          ),
                        ],
                        const SizedBox(height: 14),
                        SplitGoldCtaButton(
                          label: 'Lanjut ke Gudang & Pembeli',
                          onPressed: widget.onOpenAuth,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFourActorsSection(SimpanJualPalette p) {
    const supportingActors = [
      (
        no: '02',
        role: 'Kelompok Tani (Lot Kolektif)',
        desc:
            'Menggabungkan stok kecil 1 sampai 3 ton antaranggota lewat kode TANIJAYA sehingga menembus batas minimum 5 sampai 10 ton gudang SRG.',
      ),
      (
        no: '03',
        role: 'Pengelola Gudang Daerah',
        desc:
            'Menayangkan sisa kapasitas dan 6 ceklis kelayakan fisik gudang, lalu menyetujui sewa secara atomik tanpa bentrok kuota.',
      ),
      (
        no: '04',
        role: 'Pembeli Siaga (Koperasi & SPPG)',
        desc:
            'Memasang kebutuhan pasokan Janji Beli beserta harga acuan dan standar kadar air agar petani punya pembeli pasti.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alur Terpadu Empat Peran Pascapanen',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: p.ink),
        ),
        const SizedBox(height: 12),
        // Kartu utama lebar penuh untuk pelaku inti (Petani) agar hierarki peran menonjol jelas (R-14)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: p.frameBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: p.harvestGold, width: 1.4),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '01 · PERAN UTAMA LAPANGAN',
                      style: TextStyle(
                        color: p.goldTextOnDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Petani Padi & Jagung',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Mencatat berat dan kadar air panen, menempel pesan WhatsApp tengkulak untuk diadu dengan skema S-SRG 6%, serta mendengarkan bacaan rekomendasi suara Bahasa Indonesia.',
                      style: TextStyle(
                        color: Color(0xFFF3F7F0),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SplitGoldCtaButton(
                label: 'Masuk sebagai Petani',
                onPressed: widget.onOpenAuth,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ResponsiveThreeStageGrid(
          maxColumns: 3,
          children: supportingActors
              .map(
                (it) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            'Peran ${it.no}',
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(it.role,
                            style: TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w800, color: p.ink)),
                        const SizedBox(height: 6),
                        Text(it.desc,
                            style: TextStyle(fontSize: 13.5, color: p.inkMuted, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
