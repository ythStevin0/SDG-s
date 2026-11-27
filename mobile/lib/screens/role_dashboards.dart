import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/models.dart';
import '../widgets/server_config_dialog.dart';

// ==================== 1. DASHBOARD PENGELOLA GUDANG ====================
class GudangDashboardScreen extends StatefulWidget {
  final AppState appState;
  const GudangDashboardScreen({super.key, required this.appState});

  @override
  State<GudangDashboardScreen> createState() => _GudangDashboardScreenState();
}

class _GudangDashboardScreenState extends State<GudangDashboardScreen> {
  bool _loading = true;
  List<WarehouseItem> _warehouses = const [];
  List<RentalItem> _rentals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = widget.appState.currentUser!;
    setState(() => _loading = true);
    final whs = await widget.appState.api.fetchWarehouses(
      commodity: 'jagung',
      kabupaten: user.kabupaten,
      qtyKg: 1000,
      mine: true,
      ownerId: user.id,
    );
    final rnts = await widget.appState.api.fetchRentals(user.id, user.role);
    if (mounted) {
      setState(() {
        _warehouses = whs;
        _rentals = rnts;
        _loading = false;
      });
    }
  }

  void _editWarehouseDialog(WarehouseItem wh) {
    final tersediaCtrl = TextEditingController(text: wh.tersediaKg.toStringAsFixed(0));
    final tarifCtrl = TextEditingController(text: wh.tarifPerKgHari.toString());
    final checks = Map<String, bool>.from(wh.checklist);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Kelola ${wh.nama}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tersediaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Kapasitas Tersedia (kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tarifCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Tarif Sewa (Rp/kg/hari)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ...checks.keys.map((k) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(k.replaceAll('_', ' ')),
                      value: checks[k] == true,
                      onChanged: (v) => setModal(() => checks[k] = v ?? false),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                await widget.appState.api.updateWarehouse(wh.id, {
                  'tersediaKg': double.tryParse(tersediaCtrl.text) ?? wh.tersediaKg,
                  'tarifPerKgHari': double.tryParse(tarifCtrl.text) ?? wh.tarifPerKgHari,
                  'checklist': checks,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;
    return Scaffold(
      appBar: _roleAppBar(context, widget.appState, user.nama, 'Pengelola Gudang', _load),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Permintaan Sewa Masuk (Transaksi Atomik FOR UPDATE)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_rentals.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada pengajuan sewa masuk dari petani/poktan.'),
                    ),
                  ),
                ..._rentals.map((r) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r.requesterNama} → ${r.warehouseNama}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            Text(
                                'Volume ${formatKg(r.qtyKg)} · ${r.hari} hari · Estimasi ${formatRupiah(r.estimasiBiaya)} · Status: ${formatStatusLabel(r.status)}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (r.status == 'diajukan') ...[
                                  FilledButton(
                                    onPressed: () async {
                                      await widget.appState.api.respondRental(r.id, 'terima');
                                      await _load();
                                    },
                                    child: const Text('Terima & Potong Kapasitas'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await widget.appState.api
                                          .respondRental(r.id, 'tolak', 'Kapasitas blok sedang perawatan');
                                      await _load();
                                    },
                                    child: const Text('Tolak'),
                                  ),
                                ],
                                if (r.status == 'diterima')
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      await widget.appState.api.respondRental(r.id, 'selesai');
                                      await _load();
                                    },
                                    child: const Text('Tandai Selesai & Catat Dampak'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 18),
                const Text('Profil & Kapasitas Gudang Saya',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._warehouses.map((wh) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(wh.nama, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            'Tersedia ${formatKg(wh.tersediaKg)} / ${formatKg(wh.kapasitasKg)} · Rp${wh.tarifPerKgHari}/kg/hr'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editWarehouseDialog(wh),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

// ==================== 2. DASHBOARD PEMBELI (JANJI BELI) ====================
class PembeliDashboardScreen extends StatefulWidget {
  final AppState appState;
  const PembeliDashboardScreen({super.key, required this.appState});

  @override
  State<PembeliDashboardScreen> createState() => _PembeliDashboardScreenState();
}

class _PembeliDashboardScreenState extends State<PembeliDashboardScreen> {
  bool _loading = true;
  List<CommodityModel> _commodities = const [];
  List<DemandItem> _demands = const [];
  List<SaleItem> _sales = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = widget.appState.currentUser!;
    setState(() => _loading = true);
    final comms = await widget.appState.api.fetchCommodities();
    final dems = await widget.appState.api.fetchDemands(mine: true, buyerId: user.id);
    final sls = await widget.appState.api.fetchSales();
    if (mounted) {
      setState(() {
        _commodities = comms;
        _demands = dems;
        _sales = sls;
        _loading = false;
      });
    }
  }

  void _showAddDemandDialog() {
    var kode = _commodities.isNotEmpty ? _commodities.first.kode : 'jagung';
    final qtyCtrl = TextEditingController(text: '10000');
    final hargaCtrl = TextEditingController(text: '5900');
    final catatanCtrl = TextEditingController(text: 'Kering bersih standar pakan/SPPG');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pasang Kebutuhan Baru (Janji Beli)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kode,
                decoration:
                    const InputDecoration(labelText: 'Komoditas', border: OutlineInputBorder()),
                items: _commodities
                    .map((c) => DropdownMenuItem(value: c.kode, child: Text(c.nama)))
                    .toList(),
                onChanged: (v) => kode = v ?? 'jagung',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Volume Dibutuhkan (kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hargaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Harga Beli Acuan (Rp/kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catatanCtrl,
                decoration:
                    const InputDecoration(labelText: 'Catatan Mutu', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final user = widget.appState.currentUser!;
              await widget.appState.api.createDemand(user, {
                'commodityKode': kode,
                'qtyKg': double.tryParse(qtyCtrl.text) ?? 10000,
                'hargaAcuan': int.tryParse(hargaCtrl.text) ?? 5800,
                'kabupaten': user.kabupaten,
                'catatan': catatanCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: const Text('Tayangkan Janji Beli'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;
    return Scaffold(
      appBar: _roleAppBar(context, widget.appState, user.nama, 'Pembeli (Janji Beli)', _load),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDemandDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pasang Janji Beli'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                const Text('Penawaran Jual Masuk dari Petani/Poktan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_sales.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada penawaran jual masuk.'),
                    ),
                  ),
                ..._sales.map((s) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.sellerNama} — ${s.commodityNama} (${formatKg(s.qtyKg)})',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            Text(
                                'Harga tawar ${formatRupiah(s.hargaTawar)}/kg · Total ${formatRupiah(s.totalNilaiRp)} · Status: ${formatStatusLabel(s.status)}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (s.status == 'diajukan') ...[
                                  FilledButton(
                                    onPressed: () async {
                                      await widget.appState.api.respondSale(s.id, 'terima');
                                      await _load();
                                    },
                                    child: const Text('Terima Penawaran'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await widget.appState.api
                                          .respondSale(s.id, 'tolak', 'Kuota minggu ini penuh');
                                      await _load();
                                    },
                                    child: const Text('Tolak'),
                                  ),
                                ],
                                if (s.status == 'diterima')
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      await widget.appState.api.respondSale(s.id, 'selesai');
                                      await _load();
                                    },
                                    child: const Text('Serah Terima Selesai'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 18),
                const Text('Daftar Kebutuhan Pasokan Saya',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._demands.map((d) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text('${d.commodityNama} — ${formatRupiah(d.hargaAcuan)}/kg',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            'Terpenuhi ${formatKg(d.terpenuhiKg)} / ${formatKg(d.qtyKg)} (${d.progressPct}%) · ${formatStatusLabel(d.status)}'),
                      ),
                    )),
              ],
            ),
    );
  }
}

// ==================== 3. DASHBOARD ADMIN (SCALABILITY & OBSERVABILITY) ====================
class AdminDashboardScreen extends StatefulWidget {
  final AppState appState;
  const AdminDashboardScreen({super.key, required this.appState});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  List<CommodityModel> _commodities = const [];
  Map<String, dynamic>? _health;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final comms = await widget.appState.api.fetchCommodities();
    final h = await widget.appState.api.checkHealth();
    if (mounted) {
      setState(() {
        _commodities = comms;
        _health = h;
        _loading = false;
      });
    }
  }

  void _showAddCommodityDialog() {
    final kodeCtrl = TextEditingController(text: 'kedelai');
    final namaCtrl = TextEditingController(text: 'Kedelai Lokal Kering');
    final hargaCtrl = TextEditingController(text: '9400');
    final kaCtrl = TextEditingController(text: '13');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Komoditas Baru (Bukti Scalability JSONB)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Menambah komoditas baru otomatis menghasilkan 64 minggu histori harga, mengaktifkan backtest prediksi, cek kesiapan, dan skor gudang tanpa mengubah kode mesin hitung.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kodeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Kode Unik', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: namaCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nama Komoditas', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hargaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Harga Acuan Pasar (Rp/kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Ambang Kadar Air Simpan (%)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              await widget.appState.api.adminCreateCommodity({
                'kode': kodeCtrl.text.trim().toLowerCase(),
                'nama': namaCtrl.text.trim(),
                'satuan': 'kg',
                'hargaAwalKg': int.tryParse(hargaCtrl.text) ?? 9400,
                'params': {
                  'kadar_air_maks_pct': double.tryParse(kaCtrl.text) ?? 13,
                  'kotoran_maks_pct': 3,
                  'rusak_maks_pct': 5,
                  'susut_per_bulan': 0.004,
                  'susut_rumah_per_bulan': 0.025,
                  'biaya_pengeringan_per_kg': 160,
                  'tarif_sewa_murah': 1,
                  'tarif_sewa_mahal': 8,
                  'fasilitas_wajib': ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
                },
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: const Text('Simpan & Aktifkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;
    return Scaffold(
      appBar: _roleAppBar(context, widget.appState, user.nama, 'Admin Sistem', _load),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCommodityDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Komoditas Baru'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                if (_health != null)
                  Card(
                    color: const Color(0xFFF0FDF4),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Observabilitas Backend: ${_health!['status']}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('Arsitektur: ${_health!['architecture']}'),
                          if (_health!['pool'] != null)
                            Text('DB Pool Connections: ${jsonEncode(_health!['pool'])}',
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Konfigurasi Parameter JSONB Komoditas (F13)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._commodities.map((c) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c.nama} (${c.kode})',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                const JsonEncoder.withIndent('  ').convert(c.params.toJson()),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Color(0xFF6EE7B7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

PreferredSizeWidget _roleAppBar(
  BuildContext context,
  AppState appState,
  String nama,
  String roleLabel,
  VoidCallback onRefresh,
) {
  return AppBar(
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text('Peran: $roleLabel', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Mode Lapangan Aa+',
        onPressed: appState.toggleFieldMode,
        icon: const Icon(Icons.text_increase_rounded),
      ),
      IconButton(
        tooltip: 'Server Backend',
        onPressed: () => showServerConfigDialog(context, appState),
        icon: const Icon(Icons.dns_outlined),
      ),
      IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
      IconButton(onPressed: appState.logout, icon: const Icon(Icons.logout_rounded)),
    ],
  );
}
