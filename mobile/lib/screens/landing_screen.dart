import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/formatters.dart';
import '../core/models.dart';
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
  String _selectedKode = 'jagung';
  double _qtyKg = 5000;
  double _kadarAir = 18;
  bool _useSrgLoan = true;
  final double _panjarPerKg = 3800;

  Map<String, dynamic>? _impact;
  DecisionResult? _simDecision;
  PanjarResult? _simPanjar;
  int _latestPrice = 5200;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final imp = await widget.appState.api.fetchImpact();
    _recalculateLocal();
    if (mounted) {
      setState(() => _impact = imp);
    }
  }

  Future<void> _recalculateLocal() async {
    final pr = await widget.appState.api.fetchPrices(_selectedKode);
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
      hargaPanjarPerKg: _panjarPerKg,
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

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.appState.api.offlineFallbackMode;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.grass_rounded, color: Color(0xFF047857)),
            SizedBox(width: 8),
            Text('SimpanJual', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mode Lapangan Aa+',
            onPressed: widget.appState.toggleFieldMode,
            icon: Icon(
              Icons.text_increase_rounded,
              color: widget.appState.fieldMode ? const Color(0xFFD97706) : null,
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan Server Backend',
            onPressed: () => showServerConfigDialog(context, widget.appState),
            icon: Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              color: isOffline ? Colors.amber.shade800 : const Color(0xFF047857),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: widget.onOpenAuth,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Masuk / Demo'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isOffline
                              ? 'SEVENT X Kategori Mobile · SDG 8 (Mode Simulasi Mandiri)'
                              : 'SEVENT X Kategori Mobile · SDG 8 (Live Go Modular Monolith)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Jangan Jual Rugi Saat Panen Raya. Hitung Titik Impas, Simpan Kolektif, & Pastikan Pembeli.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'SimpanJual membantu petani kecil menghitung susut pengeringan kadar air, ongkos gudang SRG, dan bunga S-SRG 6% dibanding panjar tengkulak, terhubung ke Lot Kolektif Poktan dan pembeli siaga (Janji Beli).',
                        style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFBBF24),
                              foregroundColor: const Color(0xFF0F172A),
                              minimumSize: const Size(210, 48),
                            ),
                            onPressed: widget.onOpenAuth,
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text(
                              'Coba 1-Click Akun Demo (5 Peran)',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Ringkasan Dampak SDG 8 (F12)
                if (_impact != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _impactTile(
                        'Tambahan Pendapatan Petani',
                        formatRupiah((_impact!['tambahanPendapatanRp'] as num? ?? 4250000)),
                        Icons.trending_up_rounded,
                        const Color(0xFF047857),
                      ),
                      _impactTile(
                        'Stok Terserap Pembeli Siaga',
                        formatKg((_impact!['stokTerserapKg'] as num? ?? 10000)),
                        Icons.handshake_outlined,
                        const Color(0xFF1D4ED8),
                      ),
                      _impactTile(
                        'Estimasi Susut Pascapanen Dicegah',
                        formatKg((_impact!['susutDicegahKg'] as num? ?? 240)),
                        Icons.shield_outlined,
                        const Color(0xFFB45309),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Simulator Cepat Tanpa Login
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Simulasi Cepat Tahan vs Panjar (Tanpa Login)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Harga pasar standar saat ini: ${formatRupiah(_latestPrice)}/kg',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 14),
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
                        Text('Volume Panen: ${formatKg(_qtyKg)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
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
                        Text('Kadar Air Aktual Panen: ${_kadarAir.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
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
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Gunakan Pinjaman Subsidi S-SRG (Bunga 6%/thn, Plafon 70%)'),
                          value: _useSrgLoan,
                          onChanged: (v) {
                            setState(() => _useSrgLoan = v);
                            _recalculateLocal();
                          },
                        ),
                        if (_simDecision != null) ...[
                          const Divider(height: 24),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _simDecision!.recommendation == 'JUAL'
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _simDecision!.recommendation == 'JUAL'
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFF6EE7B7),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REKOMENDASI: ${formatStatusLabel(_simDecision!.recommendation)} (${_simDecision!.bestHorizonWeeks} MINGGU)',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Selisih vs Jual Segera: ${formatRupiah(_simDecision!.best.selisihRp, showPlus: true)} (${_simDecision!.best.selisihPct}%) · Titik Impas: ${formatRupiah(_simDecision!.best.titikImpasPerKg)}/kg',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                if (_simDecision!.perluPengeringan) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Konversi Kadar Air: Bobot kering siap simpan ${formatKg(_simDecision!.qtySiap)} (susut air ${formatKg(_simDecision!.susutPengeringanKg)})',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                                  ),
                                ],
                                if (_simPanjar != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Panjar Tandingan (Rp${formatIntId(_panjarPerKg)}/kg): Tahan stok menyelamatkan ${formatRupiah(_simPanjar!.selisihTerhadapTahanRp, showPlus: true)} dibanding panjar tengkulak!',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _impactTile(String label, String value, IconData icon, Color color) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
