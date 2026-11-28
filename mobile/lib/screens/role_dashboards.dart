import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/server_config_dialog.dart';

class GudangDashboardScreen extends StatefulWidget {
  final AppState appState;
  const GudangDashboardScreen({super.key, required this.appState});

  @override
  State<GudangDashboardScreen> createState() => _GudangDashboardScreenState();
}

class _GudangDashboardScreenState extends State<GudangDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<WarehouseItem> _warehouses = const [];
  List<RentalItem> _rentals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = widget.appState.currentUser!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
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
          title: Text('Perbarui Gudang: ${wh.nama}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tersediaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kapasitas Tersedia (kg)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tarifCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tarif Sewa (Rp/kg/hari)'),
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
                final nav = Navigator.of(ctx);
                await widget.appState.api.updateWarehouse(wh.id, {
                  'tersediaKg': double.tryParse(tersediaCtrl.text) ?? wh.tersediaKg,
                  'tarifPerKgHari': double.tryParse(tarifCtrl.text) ?? wh.tarifPerKgHari,
                  'checklist': checks,
                });
                if (ctx.mounted) nav.pop();
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
    final p = SimpanJualPalette.of(context);
    final user = widget.appState.currentUser!;
    return Scaffold(
      appBar: _roleAppBar(context, widget.appState, user.nama, 'Pengelola Gudang', _load),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: StatePanel(
                icon: Icons.warehouse_outlined,
                title: 'Memuat data kapasitas gudang & antrean sewa',
                message: 'Mengambil status transaksi atomik terkini.',
                isLoading: true,
              ),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatePanel(
                    icon: Icons.error_outline_rounded,
                    title: 'Gagal memuat panel gudang',
                    message: _error!,
                    actionLabel: 'Muat Ulang',
                    onAction: _load,
                    isError: true,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _roleStageHeader(
                      p,
                      eyebrow: 'OPERASIONAL LUMBUNG & SRG',
                      title: 'Persetujuan Sewa Ruang Simpan',
                      subtitle:
                          'Kapasitas gudang hanya terpotong saat pengajuan disetujui dan pulih otomatis ketika selesai.',
                    ),
                    const SizedBox(height: 18),
                    Text('Antrean Permintaan Sewa Petani/Poktan',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    if (_rentals.isEmpty)
                      const StatePanel(
                        icon: Icons.inbox_outlined,
                        title: 'Belum ada pengajuan sewa masuk',
                        message:
                            'Permintaan sewa baru dari petani atau ketua poktan akan muncul di daftar ini.',
                      )
                    else
                      ..._rentals.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${r.requesterNama} ke ${r.warehouseNama}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15.5,
                                              color: p.ink,
                                            ),
                                          ),
                                        ),
                                        StampBadge(label: formatStatusLabel(r.status)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LedgerRow(
                                      label: 'Volume & durasi simpan',
                                      value: '${formatKg(r.qtyKg)} • ${r.hari} hari',
                                    ),
                                    LedgerRow(
                                      label: 'Estimasi biaya sewa',
                                      value: formatRupiah(r.estimasiBiaya),
                                      emphasize: true,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (r.status == 'diajukan') ...[
                                          FilledButton(
                                            onPressed: () async {
                                              await widget.appState.api.respondRental(r.id, 'terima');
                                              await _load();
                                            },
                                            child: const Text('Setujui & Kunci Ruang'),
                                          ),
                                          OutlinedButton(
                                            onPressed: () async {
                                              await widget.appState.api.respondRental(
                                                r.id,
                                                'tolak',
                                                'Ruang simpan sedang pemeliharaan berkala',
                                              );
                                              await _load();
                                            },
                                            child: const Text('Tolak'),
                                          ),
                                        ],
                                        if (r.status == 'diterima')
                                          FilledButton(
                                            onPressed: () async {
                                              await widget.appState.api
                                                  .respondRental(r.id, 'selesai');
                                              await _load();
                                            },
                                            child: const Text('Tandai Selesai & Catat Dampak'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    const SizedBox(height: 20),
                    Text('Daftar Gudang Kelolaan Saya',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    ResponsiveThreeStageGrid(
                      maxColumns: 2,
                      children: _warehouses
                          .map((wh) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              wh.nama,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15.5,
                                                color: p.ink,
                                              ),
                                            ),
                                          ),
                                          if (wh.isSrg)
                                            const StampBadge(label: 'SRG', tone: StampTone.ok),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LedgerRow(
                                        label: 'Kapasitas tersedia',
                                        value:
                                            '${formatKg(wh.tersediaKg)} / ${formatKg(wh.kapasitasKg)}',
                                        emphasize: true,
                                      ),
                                      LedgerRow(
                                        label: 'Tarif harian',
                                        value: 'Rp${wh.tarifPerKgHari}/kg/hari',
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => _editWarehouseDialog(wh),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        label: const Text('Ubah Kapasitas & Ceklis'),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}

class PembeliDashboardScreen extends StatefulWidget {
  final AppState appState;
  const PembeliDashboardScreen({super.key, required this.appState});

  @override
  State<PembeliDashboardScreen> createState() => _PembeliDashboardScreenState();
}

class _PembeliDashboardScreenState extends State<PembeliDashboardScreen> {
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _showAddDemandDialog() {
    var kode = _commodities.isNotEmpty ? _commodities.first.kode : 'jagung';
    final qtyCtrl = TextEditingController();
    final hargaCtrl = TextEditingController();
    final catatanCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pasang Kebutuhan Pasokan (Janji Beli)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kode,
                decoration: const InputDecoration(labelText: 'Pilih Komoditas'),
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
                  labelText: 'Volume Dibutuhkan (kg)',
                  hintText: 'Contoh: 10000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hargaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Beli Acuan (Rp/kg)',
                  hintText: 'Contoh: 5900',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catatanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Syarat Mutu Singkat',
                  hintText: 'Contoh: Kering bersih bebas jamur',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final user = widget.appState.currentUser!;
              await widget.appState.api.createDemand(user, {
                'commodityKode': kode,
                'qtyKg': double.tryParse(qtyCtrl.text) ?? 10000,
                'hargaAcuan': int.tryParse(hargaCtrl.text) ?? 5800,
                'kabupaten': user.kabupaten,
                'catatan': catatanCtrl.text.trim(),
              });
              if (ctx.mounted) nav.pop();
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
    final p = SimpanJualPalette.of(context);
    final user = widget.appState.currentUser!;
    return Scaffold(
      appBar: _roleAppBar(context, widget.appState, user.nama, 'Pembeli Siaga', _load),
      floatingActionButton: SplitGoldCtaButton(
        label: 'Pasang Janji Beli',
        onPressed: _showAddDemandDialog,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: StatePanel(
                icon: Icons.storefront_outlined,
                title: 'Memuat daftar Janji Beli & penawaran petani',
                message: 'Mengambil kuota terserap terkini.',
                isLoading: true,
              ),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatePanel(
                    icon: Icons.error_outline_rounded,
                    title: 'Gagal memuat dashboard pembeli',
                    message: _error!,
                    actionLabel: 'Muat Ulang',
                    onAction: _load,
                    isError: true,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
                  children: [
                    _roleStageHeader(
                      p,
                      eyebrow: 'PENGADAAN PANGAN DAERAH & SPPG',
                      title: 'Kuota Janji Beli & Serapan Petani',
                      subtitle:
                          'Terima penawaran dari petani atau lot poktan dengan pemotongan kuota otomatis bebas bentrok.',
                    ),
                    const SizedBox(height: 18),
                    Text('Penawaran Masuk dari Petani / Poktan',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    if (_sales.isEmpty)
                      const StatePanel(
                        icon: Icons.local_shipping_outlined,
                        title: 'Belum ada penawaran masuk',
                        message:
                            'Penawaran jual dari petani terhadap pengumuman Janji Beli Anda akan tampil di sini.',
                      )
                    else
                      ..._sales.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${s.sellerNama}: ${s.commodityNama}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15.5,
                                              color: p.ink,
                                            ),
                                          ),
                                        ),
                                        StampBadge(label: formatStatusLabel(s.status)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LedgerRow(label: 'Volume ditawarkan', value: formatKg(s.qtyKg)),
                                    LedgerRow(
                                      label: 'Harga tawar & nilai total',
                                      value:
                                          '${formatRupiah(s.hargaTawar)}/kg (${formatRupiah(s.totalNilaiRp)})',
                                      emphasize: true,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
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
                                              await widget.appState.api.respondSale(
                                                s.id,
                                                'tolak',
                                                'Jadwal penerimaan gudang penuh',
                                              );
                                              await _load();
                                            },
                                            child: const Text('Tolak'),
                                          ),
                                        ],
                                        if (s.status == 'diterima')
                                          FilledButton(
                                            onPressed: () async {
                                              await widget.appState.api
                                                  .respondSale(s.id, 'selesai');
                                              await _load();
                                            },
                                            child: const Text('Tandai Serah Terima Selesai'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    const SizedBox(height: 20),
                    Text('Pengumuman Janji Beli Aktif Saya',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    ResponsiveThreeStageGrid(
                      maxColumns: 2,
                      children: _demands
                          .map((d) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${d.commodityNama} (${formatRupiah(d.hargaAcuan)}/kg)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15.5,
                                          color: p.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LedgerRow(
                                        label: 'Kuota terpenuhi',
                                        value:
                                            '${formatKg(d.terpenuhiKg)} / ${formatKg(d.qtyKg)} (${d.progressPct}%)',
                                        emphasize: true,
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: (d.progressPct / 100.0).clamp(0.0, 1.0),
                                        minHeight: 7,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final AppState appState;
  const AdminDashboardScreen({super.key, required this.appState});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<CommodityModel> _commodities = const [];
  Map<String, dynamic>? _health;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comms = await widget.appState.api.fetchCommodities();
      final h = await widget.appState.api.checkHealth();
      if (mounted) {
        setState(() {
          _commodities = comms;
          _health = h;
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

  void _showAddCommodityDialog() {
    final kodeCtrl = TextEditingController();
    final namaCtrl = TextEditingController();
    final hargaCtrl = TextEditingController();
    final kaCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Komoditas Baru (Konfigurasi JSONB)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Komoditas baru otomatis langsung mengaktifkan proyeksi harga, cek kesiapan simpan, dan skor gudang tanpa perubahan kode mesin hitung.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kode Unik Komoditas',
                  hintText: 'Contoh: kedelai',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Komoditas',
                  hintText: 'Contoh: Kedelai Kering Lokal',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hargaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Acuan Awal (Rp/kg)',
                  hintText: 'Contoh: 9400',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batas Kadar Air Simpan (%)',
                  hintText: 'Contoh: 13',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final kode =
                  kodeCtrl.text.trim().isEmpty ? 'kedelai' : kodeCtrl.text.trim().toLowerCase();
              final nama = namaCtrl.text.trim().isEmpty ? 'Kedelai Kering Lokal' : namaCtrl.text.trim();
              await widget.appState.api.adminCreateCommodity({
                'kode': kode,
                'nama': nama,
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
              if (ctx.mounted) nav.pop();
              await _load();
            },
            child: const Text('Simpan Komoditas'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);
    final user = widget.appState.currentUser!;
    return Scaffold(
      appBar: _roleAppBar(context, widget.appState, user.nama, 'Admin Sistem', _load),
      floatingActionButton: SplitGoldCtaButton(
        label: 'Tambah Komoditas',
        onPressed: _showAddCommodityDialog,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: StatePanel(
                icon: Icons.tune_rounded,
                title: 'Memuat konfigurasi sistem & kesehatan server',
                message: 'Memeriksa pool koneksi PostgreSQL dan katalog JSONB.',
                isLoading: true,
              ),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatePanel(
                    icon: Icons.error_outline_rounded,
                    title: 'Gagal memuat panel admin',
                    message: _error!,
                    actionLabel: 'Muat Ulang',
                    onAction: _load,
                    isError: true,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
                  children: [
                    _roleStageHeader(
                      p,
                      eyebrow: 'SKALABILITAS PARAMETER KOMODITAS',
                      title: 'Panel Konfigurasi JSONB & Kesehatan Backend',
                      subtitle:
                          'Tambahkan komoditas pertanian baru kapan saja tanpa mengubah kode mesin hitung Go maupun Dart.',
                    ),
                    const SizedBox(height: 16),
                    if (_health != null)
                      Card(
                        color: p.surfaceAlt,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LedgerRow(
                                label: 'Status kesehatan backend',
                                value: '${_health!['status']}',
                                emphasize: true,
                              ),
                              LedgerRow(
                                label: 'Arsitektur aktif',
                                value: '${_health!['architecture']}',
                              ),
                              if (_health!['pool'] != null)
                                LedgerRow(
                                  label: 'Pool koneksi PostgreSQL',
                                  value: jsonEncode(_health!['pool']),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text('Katalog Parameter Komoditas Aktif',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    ResponsiveThreeStageGrid(
                      maxColumns: 2,
                      children: _commodities
                          .map((c) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${c.nama} (${c.kode})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15.5,
                                              color: p.ink,
                                            ),
                                          ),
                                          StampBadge(label: 'SATUAN ${c.satuan.toUpperCase()}'),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      LedgerRow(
                                        label: 'Ambang kadar air simpan',
                                        value: '${c.params.kadarAirMaksPct}%',
                                      ),
                                      LedgerRow(
                                        label: 'Laju susut gudang vs rumah',
                                        value:
                                            '${(c.params.susutPerBulan * 100).toStringAsFixed(1)}% vs ${(c.params.susutRumahPerBulan * 100).toStringAsFixed(1)}%/bln',
                                      ),
                                      LedgerRow(
                                        label: 'Biaya jemur patokan',
                                        value: 'Rp${c.params.biayaPengeringanPerKg.toStringAsFixed(0)}/kg',
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}

Widget _roleStageHeader(
  SimpanJualPalette p, {
  required String eyebrow,
  required String title,
  required String subtitle,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [p.stageLeft, p.stageMid],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(8),
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(16),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: p.goldTextOnDark,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFEAF4EC), fontSize: 13.5, height: 1.4),
        ),
      ],
    ),
  );
}

PreferredSizeWidget _roleAppBar(
  BuildContext context,
  AppState appState,
  String nama,
  String roleLabel,
  VoidCallback onRefresh,
) {
  final p = SimpanJualPalette.of(context);
  return AppBar(
    title: Row(
      children: [
        const SimpanJualBrand(lightOnDark: true, compact: true),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            '$nama • $roleLabel',
            style: TextStyle(fontSize: 13.5, color: p.goldTextOnDark, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        tooltip: appState.darkMode ? 'Mode Terang' : 'Mode Rimbun Gelap',
        onPressed: appState.toggleDarkMode,
        icon: Icon(appState.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      ),
      IconButton(
        tooltip: 'Perbesar huruf Mode Lapangan Aa+',
        onPressed: appState.toggleFieldMode,
        icon: const Icon(Icons.format_size_rounded),
      ),
      IconButton(
        tooltip: 'Pengaturan Server Backend',
        onPressed: () => showServerConfigDialog(context, appState),
        icon: const Icon(Icons.dns_outlined),
      ),
      IconButton(
        tooltip: 'Muat Ulang Data',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      IconButton(
        tooltip: 'Keluar / Ganti Akun Peran',
        onPressed: appState.logout,
        icon: const Icon(Icons.logout_rounded),
      ),
    ],
  );
}
