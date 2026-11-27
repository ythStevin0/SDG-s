import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/models.dart';
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
  int _latestPrice = 5000;
  List<PricePoint> _series = const [];
  ForecastOutput? _forecast;
  DecisionResult? _decision;
  PanjarResult? _panjar;
  ReadinessResult? _readiness;
  String? _decisionId;
  Map<String, dynamic>? _aiExplanation;
  bool _loadingAi = false;

  // Asumsi kustom (F4)
  double _tarifSewa = 2.5;
  final double _biayaAngkut = 20;
  final double _biayaTetap = 100000;
  double _rasioPinjaman = 0.70;
  double _bungaTahunan = 0.06; // Default S-SRG 6%

  // Panjar Tandingan & Ekstrak WA (F5 & F15)
  String _panjarMode = 'per_kg';
  final _panjarCtrl = TextEditingController(text: '3800');
  final _waTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    setState(() => _loading = true);
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

      DecisionResult dec;
      if (res['decision'] is DecisionResult) {
        dec = res['decision'] as DecisionResult;
      } else {
        dec = DecisionResult.fromJson((res['decision'] as Map).cast<String, dynamic>());
      }

      PanjarResult? pj;
      if (res['panjar'] != null) {
        pj = res['panjar'] is PanjarResult
            ? res['panjar'] as PanjarResult
            : PanjarResult.fromJson((res['panjar'] as Map).cast<String, dynamic>());
      }

      ReadinessResult rd;
      if (res['readiness'] is ReadinessResult) {
        rd = res['readiness'] as ReadinessResult;
      } else {
        rd = ReadinessResult.fromJson((res['readiness'] as Map).cast<String, dynamic>());
      }

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
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghitung: $e')));
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
        title: const Text('Transparansi Rumus Ekonomi Pascapanen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Konversi Bobot Kering Siap Simpan:\n'
                  'Q_siap = Q × (100 - KA_aktual) / (100 - KA_ambang)\n'
                  '→ ${formatKg(dec.qtySiap)} (Susut pengeringan: ${formatKg(dec.susutPengeringanKg)})'),
              const SizedBox(height: 10),
              Text('2. Biaya Simpan Total (${dec.best.days} hari):\n'
                  '• Pengeringan: ${formatRupiah(dec.best.biayaPengeringan)}\n'
                  '• Sewa Gudang: ${formatRupiah(dec.best.biayaSewa)}\n'
                  '• Angkut: ${formatRupiah(dec.best.biayaAngkut)}\n'
                  '• Bunga Pinjaman: ${formatRupiah(dec.best.bungaPinjaman)}\n'
                  '• Biaya Tetap: ${formatRupiah(dec.best.biayaTetap)}\n'
                  '= Total K(t*): ${formatRupiah(dec.best.totalBiayaSimpan)}'),
              const SizedBox(height: 10),
              Text('3. Titik Impas Harga (Math.ceil):\n'
                  'P_be = ⌈ (Jual_Segera + K(t*)) / Q_eff ⌉ = ${formatRupiah(dec.best.titikImpasPerKg)}/kg'),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.stock;
    return Scaffold(
      appBar: AppBar(
        title: Text('Keputusan: ${st.commodityNama}'),
        actions: [
          IconButton(
            tooltip: 'Mode Lapangan Aa+',
            onPressed: widget.appState.toggleFieldMode,
            icon: const Icon(Icons.text_increase_rounded),
          ),
        ],
      ),
      body: _loading || _decision == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroDecisionCard(_decision!),
                      const SizedBox(height: 14),
                      if (_aiExplanation != null) _buildAiCard(_aiExplanation!),
                      if (_readiness != null) ...[
                        const SizedBox(height: 14),
                        _buildReadinessCard(_readiness!, _decision!),
                      ],
                      const SizedBox(height: 14),
                      if (_forecast != null)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tren Harga & Proyeksi Statistik (F3)',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 10),
                                PriceForecastChart(series: _series, forecast: _forecast!),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      _buildAssumptionsExpansion(),
                      const SizedBox(height: 14),
                      _buildPanjarCard(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroDecisionCard(DecisionResult dec) {
    final isTahan = dec.recommendation == 'TAHAN';
    final isRisk = dec.recommendation == 'TAHAN_BERISIKO';
    final bg = isTahan
        ? const Color(0xFF065F46)
        : isRisk
            ? const Color(0xFF92400E)
            : const Color(0xFF991B1B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stok ${formatKg(widget.stock.qtyKg)} · KA ${widget.stock.kadarAir}% · ${widget.stock.kabupaten}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'REKOMENDASI: ${formatStatusLabel(dec.recommendation)}${dec.recommendation != "JUAL" ? " (${dec.bestHorizonWeeks} MINGGU)" : ""}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Selisih Pendapatan: ${formatRupiah(dec.best.selisihRp, showPlus: true)} (${dec.best.selisihPct}%)',
            style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Titik Impas Harga: ${formatRupiah(dec.best.titikImpasPerKg)}/kg · Jual Segera: ${formatRupiah(dec.pendapatanJualSegera)}',
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Text(dec.summarySentence, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => widget.appState.speakText(
                  'Rekomendasi ${dec.recommendation.replaceAll("_", " ")}. ${dec.summarySentence} Perkiraan selisih ${formatIntId(dec.best.selisihRp.abs())} rupiah.',
                ),
                icon: Icon(widget.appState.isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded),
                label: Text(widget.appState.isSpeaking ? 'Hentikan Suara' : 'Bacakan Rekomendasi'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: () => _showFormulaDialog(dec),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('Rumus & Rincian Biaya'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: bg,
                ),
                onPressed: _loadingAi ? null : _askAiExplanation,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_loadingAi ? 'Memproses...' : 'Jelaskan Bahasa Sederhana'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(Map<String, dynamic> exp) {
    final alasan = (exp['alasan'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final langkah =
        (exp['langkah_berikut'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF99F6E4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF0F766E), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exp['fallback_used'] == true
                        ? 'Penjelasan Bahasa Petani (Template Terverifikasi)'
                        : 'Penjelasan AI Terkendali (Lolos Validator Satuan)',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF115E59)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text((exp['ringkasan'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...alasan.map((a) => Text('• $a', style: const TextStyle(fontSize: 13))),
            if (langkah.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Langkah Berikut:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ...langkah.map((l) => Text('→ $l', style: const TextStyle(fontSize: 13))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard(ReadinessResult rd, DecisionResult dec) {
    final ok = rd.status == 'LAYAK';
    return Card(
      elevation: 0,
      color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ok ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cek Kesiapan Mutu Simpan (F6): ${rd.status.replaceAll("_", " ")}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            if (dec.perluPengeringan)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Konversi KA: ${formatKg(widget.stock.qtyKg)} basah → ${formatKg(dec.qtySiap)} kering siap simpan (Ongkos jemur ${formatRupiah(dec.best.biayaPengeringan)})',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
              ),
            const SizedBox(height: 6),
            ...rd.reasons.map((r) => Text('• $r', style: const TextStyle(fontSize: 13))),
            ...rd.actions.map((a) => Text('✓ Aksi: $a',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Widget _buildAssumptionsExpansion() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: ExpansionTile(
        title: const Text('Ubah Asumsi Biaya & Bunga S-SRG (F4)',
            style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          'Sewa Rp$_tarifSewa/kg/hr · Bunga ${(_bungaTahunan * 100).toStringAsFixed(0)}%/thn · Pinjaman ${(_rasioPinjaman * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12.5),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
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
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ambil Pembiayaan Resi Gudang (70% Nilai Stok)'),
            value: _rasioPinjaman > 0,
            onChanged: (v) {
              setState(() => _rasioPinjaman = v ? 0.70 : 0.0);
              _evaluate();
            },
          ),
          Text('Tarif Sewa Gudang: Rp${_tarifSewa.toStringAsFixed(1)}/kg/hari'),
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
    );
  }

  Widget _buildPanjarCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panjar Tandingan vs Tengkulak & Ekstrak WA (F5 & F15)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: _waTextCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Tempel pesan WhatsApp tengkulak (opsional, F15)',
                hintText: 'Contoh: Pak Slamet jagungnya saya panjar Rp3.700/kg 5 ton ya',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Ekstrak Otomatis',
                  onPressed: _extractWa,
                  icon: const Icon(Icons.content_paste_go_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'per_kg', label: Text('Harga Per Kg (Rp/kg)')),
                ButtonSegment(value: 'borongan', label: Text('Tebasan Borongan (Rp Total)')),
              ],
              selected: {_panjarMode},
              onSelectionChanged: (s) => setState(() {
                _panjarMode = s.first;
                _panjarCtrl.text = _panjarMode == 'borongan' ? '18500000' : '3800';
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _panjarCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _panjarMode == 'borongan'
                          ? 'Total Tawaran Borongan (Rp)'
                          : 'Harga Panjar Tengkulak (Rp/kg)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(110, 52)),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potongan Tengkulak terhadap Pasar: ${_panjar!.diskonTerhadapPasarPct}% lebih murah',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Uang Tunai Hari Ini: Panjar ${formatRupiahCompact(_panjar!.tunaiHariIniPanjarRp)} vs Plafon SRG ${formatRupiahCompact(_panjar!.tunaiHariIniSrgRp)}',
                    ),
                    Text(
                      '• Hasil Bersih Akhir: Panjar ${formatRupiahCompact(_panjar!.pendapatanPanjarRp)} vs Tahan ${formatRupiahCompact(_panjar!.pendapatanTahanRp)}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selisih diselamatkan jika tidak ambil panjar: ${formatRupiah(_panjar!.selisihTerhadapTahanRp, showPlus: true)} (${_panjar!.selisihTerhadapTahanPct}%)',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857)),
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
