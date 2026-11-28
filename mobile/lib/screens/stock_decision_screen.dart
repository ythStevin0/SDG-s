import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/price_forecast_chart.dart';

class StockDecisionScreen extends StatefulWidget {
  final AppState appState;
  final StockItem stock;

  const StockDecisionScreen({
    super.key,
    required this.appState,
    required this.stock,
  });

  @override
  State<StockDecisionScreen> createState() => _StockDecisionScreenState();
}

class _StockDecisionScreenState extends State<StockDecisionScreen> {
  bool _loading = true;
  String? _error;
  int _latestPrice = 5000;
  List<PricePoint> _series = const [];
  ForecastOutput? _forecast;
  DecisionResult? _decision;
  PanjarResult? _panjar;
  ReadinessResult? _readiness;
  String? _decisionId;
  Map<String, dynamic>? _aiExplanation;
  bool _loadingAi = false;

  double _tarifSewa = 2.5;
  final double _biayaAngkut = 20;
  final double _biayaTetap = 100000;
  double _rasioPinjaman = 0.70;
  double _bungaTahunan = 0.06;

  String _panjarMode = 'per_kg';
  final _panjarCtrl = TextEditingController(text: '3800');
  final _waTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void dispose() {
    _panjarCtrl.dispose();
    _waTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _evaluate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pr = await widget.appState.api.fetchPrices(widget.stock.commodityKode);
      final parsedPanjar = double.tryParse(_panjarCtrl.text.replaceAll('.', '')) ?? 0;

      final res = await widget.appState.api.evaluateStockDecision(widget.stock, {
        'tarifSewaPerKgHari': _tarifSewa,
        'biayaAngkutPerKg': _biayaAngkut,
        'biayaTetap': _biayaTetap,
        'rasioPinjaman': _rasioPinjaman,
        'bungaTahunan': _bungaTahunan,
        'panjarMode': _panjarMode,
        if (_panjarMode == 'per_kg' && parsedPanjar > 0) 'hargaPanjarPerKg': parsedPanjar,
        if (_panjarMode == 'borongan' && parsedPanjar > 0) 'totalBoronganRp': parsedPanjar,
      });

      final dec = res['decision'] is DecisionResult
          ? res['decision'] as DecisionResult
          : DecisionResult.fromJson((res['decision'] as Map).cast<String, dynamic>());

      PanjarResult? pj;
      if (res['panjar'] != null) {
        pj = res['panjar'] is PanjarResult
            ? res['panjar'] as PanjarResult
            : PanjarResult.fromJson((res['panjar'] as Map).cast<String, dynamic>());
      }

      final rd = res['readiness'] is ReadinessResult
          ? res['readiness'] as ReadinessResult
          : ReadinessResult.fromJson((res['readiness'] as Map).cast<String, dynamic>());

      if (mounted) {
        setState(() {
          _series = pr.series;
          _forecast = pr.forecast;
          _latestPrice = (res['latestPrice'] as num? ?? pr.latestPrice).round();
          _decision = dec;
          _panjar = pj;
          _readiness = rd;
          _decisionId = res['decisionId']?.toString();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _askAiExplanation() async {
    if (_decision == null || _forecast == null) return;
    setState(() => _loadingAi = true);
    final exp = await widget.appState.api.explainAI({
      'decisionId': _decisionId,
      'komoditas': widget.stock.commodityNama,
      'rekomendasi': _decision!.recommendation,
      'horizonMinggu': _decision!.bestHorizonWeeks,
      'selisihRp': _decision!.best.selisihRp,
      'selisihPct': _decision!.best.selisihPct,
      'titikImpasPerKg': _decision!.best.titikImpasPerKg,
      'hargaSekarangPerKg': _latestPrice,
      'totalBiayaSimpan': _decision!.best.totalBiayaSimpan,
      'mapePct': _forecast!.mapePct,
    });
    if (mounted) {
      setState(() {
        _aiExplanation = exp;
        _loadingAi = false;
      });
    }
  }

  Future<void> _extractWa() async {
    final txt = _waTextCtrl.text.trim();
    if (txt.isEmpty) return;
    final res = await widget.appState.api.extractWaOffer(txt);
    setState(() {
      if (res['harga_total_borongan'] != null) {
        _panjarMode = 'borongan';
        _panjarCtrl.text = res['harga_total_borongan'].toString();
      } else if (res['harga_per_kg'] != null) {
        _panjarMode = 'per_kg';
        _panjarCtrl.text = res['harga_per_kg'].toString();
      }
    });
    await _evaluate();
  }

  void _showFormulaDialog(DecisionResult dec) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rincian Rumus Ekonomi Pascapanen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Konversi Bobot Kering Siap Simpan:\n'
                  'Q_siap = Q x (100 - KA_aktual) / (100 - KA_ambang)\n'
                  'Hasil: ${formatKg(dec.qtySiap)} (Susut jemur: ${formatKg(dec.susutPengeringanKg)})'),
              const SizedBox(height: 10),
              Text('2. Total Biaya Simpan (${dec.best.days} hari):\n'
                  '- Pengeringan: ${formatRupiah(dec.best.biayaPengeringan)}\n'
                  '- Sewa Gudang: ${formatRupiah(dec.best.biayaSewa)}\n'
                  '- Angkut: ${formatRupiah(dec.best.biayaAngkut)}\n'
                  '- Bunga Pinjaman: ${formatRupiah(dec.best.bungaPinjaman)}\n'
                  '- Biaya Tetap: ${formatRupiah(dec.best.biayaTetap)}\n'
                  'Total K(t*): ${formatRupiah(dec.best.totalBiayaSimpan)}'),
              const SizedBox(height: 10),
              Text('3. Titik Impas Harga (pembulatan ke atas):\n'
                  'P_be = ceil((Jual_Segera + K(t*)) / Q_eff) = ${formatRupiah(dec.best.titikImpasPerKg)}/kg'),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup Rincian')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final st = widget.stock;

    return Scaffold(
      appBar: AppBar(
        title: Text('Keputusan: ${st.commodityNama}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: widget.appState.darkMode ? 'Mode Terang' : 'Mode Rimbun Gelap',
            onPressed: widget.appState.toggleDarkMode,
            icon: Icon(
              widget.appState.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Perbesar huruf Mode Lapangan Aa+',
            onPressed: widget.appState.toggleFieldMode,
            icon: const Icon(Icons.format_size_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: StatePanel(
                icon: Icons.hourglass_top_rounded,
                title: 'Menghitung proyeksi harga dan titik impas',
                message: 'Mengevaluasi konversi kadar air, biaya simpan, dan deret waktu historis.',
                isLoading: true,
              ),
            )
          : _error != null || _decision == null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatePanel(
                    icon: Icons.error_outline_rounded,
                    title: 'Gagal memuat perhitungan stok',
                    message: _error ?? 'Data keputusan tidak tersedia.',
                    actionLabel: 'Coba Hitung Ulang',
                    onAction: _evaluate,
                    isError: true,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBotanicalDecisionStage(p, _decision!),
                          const SizedBox(height: 16),
                          if (_aiExplanation != null) ...[
                            _buildPlainLanguageCard(p, _aiExplanation!),
                            const SizedBox(height: 16),
                          ],
                          ResponsiveThreeStageGrid(
                            maxColumns: 2,
                            spacing: 16,
                            children: [
                              if (_readiness != null) _buildReadinessCard(p, _readiness!, _decision!),
                              _buildAssumptionsCard(p),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_forecast != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Apakah proyeksi harga 4 hingga 12 minggu melampaui titik impas ${formatRupiah(_decision!.best.titikImpasPerKg)}/kg?',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w900,
                                        color: p.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    PriceForecastChart(
                                      series: _series,
                                      forecast: _forecast!,
                                      breakEvenPerKg: _decision!.best.titikImpasPerKg,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          _buildPanjarCard(p),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildBotanicalDecisionStage(SimpanJualPalette p, DecisionResult dec) {
    final recLabel = dec.recommendation == 'JUAL'
        ? 'JUAL SEKARANG'
        : '${formatStatusLabel(dec.recommendation)} ${dec.bestHorizonWeeks} MINGGU';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.stageLeft, p.stageMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: p.harvestGold, width: 1.3),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STOK ${formatKg(widget.stock.qtyKg).toUpperCase()} • KA ${widget.stock.kadarAir}% • ${widget.stock.kabupaten.toUpperCase()}',
            style: TextStyle(
              color: p.goldTextOnDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selisih bersih: ${formatRupiah(dec.best.selisihRp, showPlus: true)} (${dec.best.selisihPct}%) • Titik impas: ${formatRupiah(dec.best.titikImpasPerKg)}/kg',
            style: TextStyle(
              color: p.goldTextOnDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dec.summarySentence,
            style: const TextStyle(color: Color(0xFFEAF4EC), fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SplitGoldCtaButton(
                label: widget.appState.isSpeaking ? 'Hentikan Suara' : 'Bacakan Rekomendasi',
                onPressed: () => widget.appState.speakText(
                  'Rekomendasi $recLabel. ${dec.summarySentence} Perkiraan selisih ${formatIntId(dec.best.selisihRp.abs())} rupiah.',
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                onPressed: () => _showFormulaDialog(dec),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Lihat Rumus & Biaya'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.goldTextOnDark,
                  side: BorderSide(color: p.harvestGold),
                ),
                onPressed: _loadingAi ? null : _askAiExplanation,
                icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                label: Text(_loadingAi ? 'Menyusun kalimat...' : 'Penjelasan Bahasa Petani'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLanguageCard(SimpanJualPalette p, Map<String, dynamic> exp) {
    final alasan = (exp['alasan'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final langkah =
        (exp['langkah_berikut'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    return Card(
      color: p.surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StampBadge(
              label: exp['fallback_used'] == true
                  ? 'RINGKASAN PENYULUH (TERVERIFIKASI)'
                  : 'PENJELASAN TERVALIDASI SATUAN',
              tone: StampTone.ok,
            ),
            const SizedBox(height: 10),
            Text(
              (exp['ringkasan'] ?? '').toString(),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.ink),
            ),
            const SizedBox(height: 8),
            ...alasan.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('- $a', style: TextStyle(fontSize: 13.5, color: p.inkMuted)),
                )),
            if (langkah.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Langkah tindak lanjut:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: p.ink)),
              ...langkah.map((l) => Text('- $l', style: TextStyle(fontSize: 13.5, color: p.ink))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard(SimpanJualPalette p, ReadinessResult rd, DecisionResult dec) {
    final ok = rd.status == 'LAYAK';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kesiapan Mutu Simpan',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: p.ink)),
                StampBadge(
                  label: formatStatusLabel(rd.status),
                  tone: ok ? StampTone.ok : StampTone.warn,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (dec.perluPengeringan) ...[
              LedgerRow(
                label: 'Bobot kering sesudah jemur',
                value: '${formatKg(dec.qtySiap)} (-${formatKg(dec.susutPengeringanKg)})',
                emphasize: true,
              ),
              LedgerRow(
                label: 'Estimasi ongkos penjemuran',
                value: formatRupiah(dec.best.biayaPengeringan),
              ),
              const Divider(height: 16),
            ],
            ...rd.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('- $r', style: TextStyle(fontSize: 13, color: p.inkMuted)),
                )),
            const SizedBox(height: 4),
            ...rd.actions.map((a) => Text(
                  'Tindakan: $a',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAssumptionsCard(SimpanJualPalette p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asumsi Biaya & Skema Bunga Resi Gudang',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: p.ink)),
            const SizedBox(height: 10),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.06, label: Text('Subsidi S-SRG 6%')),
                ButtonSegment(value: 0.12, label: Text('Komersial 12%')),
              ],
              selected: {_bungaTahunan},
              onSelectionChanged: (s) {
                setState(() => _bungaTahunan = s.first);
                _evaluate();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Ambil dana talangan SRG (70% nilai stok)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink)),
              value: _rasioPinjaman > 0,
              onChanged: (v) {
                setState(() => _rasioPinjaman = v ? 0.70 : 0.0);
                _evaluate();
              },
            ),
            LedgerRow(
              label: 'Tarif sewa gudang',
              value: 'Rp${_tarifSewa.toStringAsFixed(1)}/kg/hari',
              emphasize: true,
            ),
            Slider(
              value: _tarifSewa,
              min: 1.0,
              max: 8.0,
              divisions: 14,
              onChanged: (v) => setState(() => _tarifSewa = v),
              onChangeEnd: (_) => _evaluate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanjarCard(SimpanJualPalette p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adu Tawaran Panjar Tengkulak & Ekstrak Pesan WhatsApp',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: p.ink)),
            const SizedBox(height: 10),
            TextField(
              controller: _waTextCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Tempel teks tawaran WhatsApp tengkulak (opsional)',
                hintText: 'Contoh: Pak Slamet jagungnya saya panjar Rp3.700/kg 5 ton',
                suffixIcon: IconButton(
                  tooltip: 'Baca nominal otomatis dari pesan',
                  onPressed: _extractWa,
                  icon: const Icon(Icons.input_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'per_kg', label: Text('Harga Per Kg')),
                ButtonSegment(value: 'borongan', label: Text('Tebasan Total (Rp)')),
              ],
              selected: {_panjarMode},
              onSelectionChanged: (s) => setState(() {
                _panjarMode = s.first;
                _panjarCtrl.text = _panjarMode == 'borongan' ? '18500000' : '3800';
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _panjarCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _panjarMode == 'borongan'
                          ? 'Total Uang Tebasan Borongan (Rp)'
                          : 'Harga Panjar per Kg (Rp/kg)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _evaluate,
                  child: const Text('Bandingkan'),
                ),
              ],
            ),
            if (_panjar != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LedgerRow(
                      label: 'Potongan tengkulak di bawah harga pasar',
                      value: '${_panjar!.diskonTerhadapPasarPct}%',
                      emphasize: true,
                      valueColor: p.dangerInk,
                    ),
                    LedgerRow(
                      label: 'Tunai diterima hari ini (Panjar vs Plafon SRG)',
                      value:
                          '${formatRupiahCompact(_panjar!.tunaiHariIniPanjarRp)} vs ${formatRupiahCompact(_panjar!.tunaiHariIniSrgRp)}',
                    ),
                    LedgerRow(
                      label: 'Hasil bersih akhir (Panjar vs Tahan Gudang)',
                      value:
                          '${formatRupiahCompact(_panjar!.pendapatanPanjarRp)} vs ${formatRupiahCompact(_panjar!.pendapatanTahanRp)}',
                    ),
                    const Divider(height: 14),
                    LedgerRow(
                      label: 'Pendapatan petani yang diselamatkan',
                      value:
                          '${formatRupiah(_panjar!.selisihTerhadapTahanRp, showPlus: true)} (${_panjar!.selisihTerhadapTahanPct}%)',
                      emphasize: true,
                      valueColor: p.okInk,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
