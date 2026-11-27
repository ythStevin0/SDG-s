import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/formatters.dart';
import '../core/models.dart';
import '../widgets/price_forecast_chart.dart';
import '../widgets/server_config_dialog.dart';
import '../widgets/warehouse_map_card.dart';
import 'stock_decision_screen.dart';

class PetaniShell extends StatefulWidget {
  final AppState appState;

  const PetaniShell({super.key, required this.appState});

  @override
  State<PetaniShell> createState() => _PetaniShellState();
}

class _PetaniShellState extends State<PetaniShell> {
  int _navIndex = 0;
  bool _loading = true;

  List<CommodityModel> _commodities = const [];
  List<StockItem> _stocks = const [];
  List<WarehouseItem> _warehouses = const [];
  List<GroupItem> _groups = const [];
  List<LotItem> _lots = const [];
  List<DemandItem> _demands = const [];
  List<RentalItem> _rentals = const [];
  List<SaleItem> _sales = const [];

  String _selectedPriceComm = 'jagung';
  List<PricePoint> _priceSeries = const [];
  ForecastOutput? _forecast;
  int _latestPrice = 0;

  String _whFilterComm = 'jagung';
  bool _onlySrg = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final user = widget.appState.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final comms = await widget.appState.api.fetchCommodities();
      final stocks = await widget.appState.api.fetchStocks(user.id);
      final pr = await widget.appState.api.fetchPrices(_selectedPriceComm);
      final whs = await widget.appState.api.fetchWarehouses(
        commodity: _whFilterComm,
        kabupaten: user.kabupaten,
        qtyKg: stocks.isNotEmpty && stocks.first.freeKg > 0 ? stocks.first.freeKg : 5000,
        onlySrg: _onlySrg,
      );
      final grps = await widget.appState.api.fetchGroups(user.id);
      final lots = await widget.appState.api.fetchLots(user.id);
      final dems = await widget.appState.api.fetchDemands();
      final rnts = await widget.appState.api.fetchRentals(user.id, user.role);
      final sls = await widget.appState.api.fetchSales();

      if (mounted) {
        setState(() {
          _commodities = comms;
          _stocks = stocks;
          _priceSeries = pr.series;
          _forecast = pr.forecast;
          _latestPrice = pr.latestPrice;
          _warehouses = whs;
          _groups = grps;
          _lots = lots;
          _demands = dems;
          _rentals = rnts;
          _sales = sls;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error memuat data: $e')));
      }
    }
  }

  Future<void> _openWhatsApp(String? wa, String message) async {
    if (wa == null || wa.contains('*')) return;
    final clean = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAddStockSheet() {
    final user = widget.appState.currentUser!;
    var kode = _commodities.isNotEmpty ? _commodities.first.kode : 'jagung';
    final qtyCtrl = TextEditingController(text: '3500');
    final kaCtrl = TextEditingController(text: '16.5');
    final catatanCtrl = TextEditingController();
    var kab = user.kabupaten;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setModal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Catat Stok Panen Baru (F2)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: kode,
                  decoration: const InputDecoration(labelText: 'Komoditas', border: OutlineInputBorder()),
                  items: _commodities
                      .map((c) => DropdownMenuItem(value: c.kode, child: Text('${c.nama} (${c.kode})')))
                      .toList(),
                  onChanged: (v) => setModal(() => kode = v ?? 'jagung'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Jumlah Panen (kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Kadar Air Aktual (%)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: SimpanJualEngine.jatengCoords.containsKey(kab) ? kab : 'Banyumas',
                  decoration: const InputDecoration(labelText: 'Kabupaten', border: OutlineInputBorder()),
                  items: SimpanJualEngine.jatengCoords.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setModal(() => kab = v ?? 'Banyumas'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catatanCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Catatan Mutu / Blok Sawah', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    final qty = double.tryParse(qtyCtrl.text) ?? 0;
                    final ka = double.tryParse(kaCtrl.text.replaceAll(',', '.')) ?? 14;
                    if (qty <= 0) return;
                    await widget.appState.api.createStock(user.id, {
                      'commodityKode': kode,
                      'qtyKg': qty,
                      'kadarAir': ka,
                      'kabupaten': kab,
                      'catatan': catatanCtrl.text.trim(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _refreshAll();
                  },
                  child: const Text('Simpan Stok'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRentalDialog(WarehouseItem wh) {
    final freeStocks = _stocks.where((s) => s.freeKg > 0).toList();
    final readyLots = _lots
        .where((l) => l.isKetua && (l.status == 'siap_ajukan' || l.status == 'mengumpulkan'))
        .toList();
    var useLot = freeStocks.isEmpty && readyLots.isNotEmpty;
    String? selectedStockId = freeStocks.isNotEmpty ? freeStocks.first.id : null;
    String? selectedLotId = readyLots.isNotEmpty ? readyLots.first.id : null;
    final qtyCtrl = TextEditingController(
      text: (useLot
              ? (readyLots.isNotEmpty ? readyLots.first.terkumpulKg : wh.minVolumeKg)
              : (freeStocks.isNotEmpty ? freeStocks.first.freeKg : wh.minVolumeKg))
          .toStringAsFixed(0),
    );
    final hariCtrl = TextEditingController(text: wh.minHari.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Ajukan Sewa Atomik — ${wh.nama}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Min. volume ${formatKg(wh.minVolumeKg)} · Min. ${wh.minHari} hari · Tarif Rp${wh.tarifPerKgHari}/kg/hr',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                if (readyLots.isNotEmpty && freeStocks.isNotEmpty)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Stok Mandiri')),
                      ButtonSegment(value: true, label: Text('Lot Poktan')),
                    ],
                    selected: {useLot},
                    onSelectionChanged: (s) => setModal(() => useLot = s.first),
                  ),
                const SizedBox(height: 12),
                if (!useLot && freeStocks.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedStockId,
                    decoration: const InputDecoration(
                        labelText: 'Pilih Stok Bebas', border: OutlineInputBorder()),
                    items: freeStocks
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text('${s.commodityNama} (${formatKg(s.freeKg)} bebas)'),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => selectedStockId = v),
                  ),
                if (useLot && readyLots.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedLotId,
                    decoration: const InputDecoration(
                        labelText: 'Pilih Lot Kolektif', border: OutlineInputBorder()),
                    items: readyLots
                        .map((l) => DropdownMenuItem(
                              value: l.id,
                              child: Text('${l.groupNama} (${formatKg(l.terkumpulKg)})'),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => selectedLotId = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Volume Diajukan (kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hariCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Durasi Simpan (hari)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.appState.api.submitRental(widget.appState.currentUser!, {
                    if (!useLot) 'stockId': selectedStockId,
                    if (useLot) 'lotId': selectedLotId,
                    'warehouseId': wh.id,
                    'qtyKg': double.tryParse(qtyCtrl.text) ?? 0,
                    'hari': int.tryParse(hariCtrl.text) ?? 30,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _refreshAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengajuan sewa berhasil dikirim secara atomik!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Kirim Pengajuan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaleDialog(DemandItem dem) {
    final matchingStocks =
        _stocks.where((s) => s.freeKg > 0 && s.commodityKode == dem.commodityKode).toList();
    if (matchingStocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anda belum memiliki stok bebas ${dem.commodityNama}')),
      );
      return;
    }
    var stockId = matchingStocks.first.id;
    final qtyCtrl = TextEditingController(
      text: matchingStocks.first.freeKg.clamp(1, dem.sisaKuotaKg).toStringAsFixed(0),
    );
    final tawarCtrl = TextEditingController(text: dem.hargaAcuan.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Ajukan Jual ke ${dem.buyerNama}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sisa kuota pembeli: ${formatKg(dem.sisaKuotaKg)} · Harga acuan ${formatRupiah(dem.hargaAcuan)}/kg',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: stockId,
                decoration:
                    const InputDecoration(labelText: 'Pilih Stok Bebas', border: OutlineInputBorder()),
                items: matchingStocks
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.commodityNama} (${formatKg(s.freeKg)})'),
                        ))
                    .toList(),
                onChanged: (v) => setModal(() => stockId = v ?? stockId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Volume Ditawarkan (kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tawarCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Harga Tawar (Rp/kg)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.appState.api.submitSale(widget.appState.currentUser!, {
                    'stockId': stockId,
                    'demandId': dem.id,
                    'qtyKg': double.tryParse(qtyCtrl.text) ?? 0,
                    'hargaTawar': int.tryParse(tawarCtrl.text) ?? dem.hargaAcuan,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _refreshAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Penawaran jual terkirim!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Ajukan Jual'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;
    final wide = MediaQuery.sizeOf(context).width >= 820;

    final bodyContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _navIndex,
            children: [
              _buildStokDanHargaTab(),
              _buildSimpanDanLotTab(),
              _buildJualDanRiwayatTab(),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Peran: Petani/Poktan · ${user.kabupaten}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
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
            tooltip: 'Pengaturan Server',
            onPressed: () => showServerConfigDialog(context, widget.appState),
            icon: Icon(
              widget.appState.api.offlineFallbackMode
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Muat Ulang',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Keluar / Ganti Peran',
            onPressed: widget.appState.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddStockSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Catat Stok'),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _navIndex,
              onDestinationSelected: (i) => setState(() => _navIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: 'Stok & Harga',
                ),
                NavigationDestination(
                  icon: Icon(Icons.warehouse_outlined),
                  selectedIcon: Icon(Icons.warehouse_rounded),
                  label: 'Simpan & Lot',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: 'Jual & Status',
                ),
              ],
            ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _navIndex,
                  onDestinationSelected: (i) => setState(() => _navIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: Text('Stok & Harga'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.warehouse_outlined),
                      selectedIcon: Icon(Icons.warehouse_rounded),
                      label: Text('Simpan & Lot'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront_rounded),
                      label: Text('Jual & Status'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
    );
  }

  Widget _buildStokDanHargaTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          const Text('Stok Panen Saya (Ketuk Hitung Keputusan)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (_stocks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Belum ada stok tercatat. Ketuk tombol "Catat Stok" di kanan bawah.'),
              ),
            ),
          ..._stocks.map((st) {
            final perluJemur = st.kadarAir > st.commodityParams.kadarAirMaksPct;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(st.commodityNama,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                        Chip(
                          label: Text(formatStatusLabel(st.status),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text('Panen ${st.tglPanen} · ${st.kabupaten}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _metricChip('Total', formatKg(st.qtyKg)),
                        const SizedBox(width: 8),
                        _metricChip('Terkunci', formatKg(st.reservedKg)),
                        const SizedBox(width: 8),
                        _metricChip('Bebas', formatKg(st.freeKg), highlight: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      perluJemur
                          ? 'Kadar Air ${st.kadarAir}% (Perlu jemur ke ≤ ${st.commodityParams.kadarAirMaksPct}%)'
                          : 'Kadar Air ${st.kadarAir}% (Layak simpan gudang ✓)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: perluJemur ? const Color(0xFFB45309) : const Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StockDecisionScreen(appState: widget.appState, stock: st),
                              ),
                            ),
                            icon: const Icon(Icons.calculate_outlined),
                            label: const Text('Hitung Tahan vs Jual & Panjar'),
                          ),
                        ),
                        if (st.reservedKg == 0 && st.soldKg == 0) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Hapus Stok',
                            onPressed: () async {
                              await widget.appState.api.deleteStock(st.id);
                              await _refreshAll();
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('Tren Harga Pasar & Prediksi (F3)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      DropdownButton<String>(
                        value: _commodities.any((c) => c.kode == _selectedPriceComm)
                            ? _selectedPriceComm
                            : (_commodities.isNotEmpty ? _commodities.first.kode : 'jagung'),
                        items: _commodities
                            .map((c) => DropdownMenuItem(value: c.kode, child: Text(c.nama)))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _selectedPriceComm = v);
                          await _refreshAll();
                        },
                      ),
                    ],
                  ),
                  Text('Harga terkini: ${formatRupiah(_latestPrice)}/kg (Data Ilustrasi Jateng)',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 12),
                  if (_forecast != null)
                    PriceForecastChart(series: _priceSeries, forecast: _forecast!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpanDanLotTab() {
    final user = widget.appState.currentUser!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Peta & Skor Gudang (F8/F9)'),
              Tab(text: 'Lot Kolektif Poktan (F7)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Sub-tab 1: Peta & Gudang
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: _commodities.any((c) => c.kode == _whFilterComm)
                              ? _whFilterComm
                              : 'jagung',
                          items: _commodities
                              .map((c) =>
                                  DropdownMenuItem(value: c.kode, child: Text('Komoditas: ${c.nama}')))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _whFilterComm = v);
                            await _refreshAll();
                          },
                        ),
                        FilterChip(
                          label: const Text('Hanya Gudang SRG'),
                          selected: _onlySrg,
                          onSelected: (v) async {
                            setState(() => _onlySrg = v);
                            await _refreshAll();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WarehouseMapCard(
                      farmerKabupaten: user.kabupaten,
                      warehouses: _warehouses,
                      onSelectWarehouse: (wh) {
                        if (wh.score.isEligible) _showRentalDialog(wh);
                      },
                    ),
                    const SizedBox(height: 14),
                    ..._warehouses.map((wh) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: wh.score.isEligible
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(wh.nama,
                                          style: const TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.w800)),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: wh.score.isEligible
                                            ? const Color(0xFF047857)
                                            : Colors.grey.shade400,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        wh.score.isEligible
                                            ? 'Skor ${wh.score.totalScore}/100'
                                            : 'Tidak Memenuhi',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${wh.kabupaten} (~${wh.score.distanceKm} km) · Tersedia ${formatKg(wh.tersediaKg)} · Tarif Rp${wh.tarifPerKgHari}/kg/hr',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                                ),
                                if (!wh.score.isEligible && wh.score.ineligibleReason != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Alasan: ${wh.score.ineligibleReason}',
                                      style: const TextStyle(
                                          color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                                    ),
                                  )
                                else ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Rincian Skor Anti-NaN: Fasilitas ${wh.score.fasilitasWajib}/30 · Kondisi/SRG ${wh.score.kondisiDanSrg}/30 · Jarak ${wh.score.jarak}/15 · Tarif ${wh.score.tarif}/15 · Kapasitas ${wh.score.kapasitas}/10',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.icon(
                                    onPressed: () => _showRentalDialog(wh),
                                    icon: const Icon(Icons.lock_clock_outlined),
                                    label: const Text('Ajukan Sewa Atomik'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )),
                  ],
                ),

                // Sub-tab 2: Lot Kolektif Poktan
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showJoinGroupDialog,
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Gabung Kode Poktan'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _showCreateGroupOrLotDialog,
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Buat Poktan / Lot'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_groups.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _groups
                            .map((g) => Chip(
                                  avatar: const Icon(Icons.groups_rounded, size: 18),
                                  label: Text('${g.nama} · Kode: ${g.kodeGabung}'),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    ..._lots.map((lt) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${lt.groupNama} — Lot ${lt.commodityNama}',
                                    style:
                                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                Text(
                                  'Terkumpul ${formatKg(lt.terkumpulKg)} / ${formatKg(lt.targetKg)} (${lt.progressPct}%) · Status: ${formatStatusLabel(lt.status)}',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: (lt.progressPct / 100.0).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                const SizedBox(height: 10),
                                ...lt.contributions.map((c) => Text(
                                      '• ${c.userNama}: ${formatKg(c.qtyKg)} (${c.sharePct}% porsi)',
                                      style: const TextStyle(fontSize: 12.5),
                                    )),
                                const SizedBox(height: 10),
                                if (lt.status == 'mengumpulkan' || lt.status == 'siap_ajukan')
                                  FilledButton.tonalIcon(
                                    onPressed: () => _showContributeLotDialog(lt),
                                    icon: const Icon(Icons.merge_type_rounded),
                                    label: const Text('Sumbang Stok Bebas ke Lot Ini'),
                                  ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJualDanRiwayatTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Bursa Janji Beli (F10/F11)'),
              Tab(text: 'Status Sewa & Jual'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: _demands.map((d) {
                    final hasMatch =
                        _stocks.any((s) => s.freeKg > 0 && s.commodityKode == d.commodityKode);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: hasMatch ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${d.commodityNama} — ${d.buyerNama}',
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w800)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${formatRupiah(d.hargaAcuan)}/kg',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${d.kabupaten} · Dibutuhkan: ${d.dibutuhkanPada} · Sisa Kuota: ${formatKg(d.sisaKuotaKg)}',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                            ),
                            if (d.catatanMutu != null)
                              Text('Syarat mutu: ${d.catatanMutu}',
                                  style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (d.progressPct / 100.0).clamp(0.0, 1.0),
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (hasMatch)
                                  const Chip(
                                    label: Text('Cocok dengan Stok Anda ✓',
                                        style: TextStyle(fontSize: 11.5)),
                                    backgroundColor: Color(0xFFDCFCE7),
                                  ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () => _showSaleDialog(d),
                                  child: const Text('Ajukan Jual'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Riwayat Sewa & Jual
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Pengajuan Sewa Gudang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (_rentals.isEmpty)
                      const Text('Belum ada pengajuan sewa.',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ..._rentals.map((r) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text('${r.warehouseNama} (${formatKg(r.qtyKg)} · ${r.hari} hr)'),
                            subtitle: Text(
                                'Biaya est. ${formatRupiah(r.estimasiBiaya)} · Status: ${formatStatusLabel(r.status)}'),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                if (r.status == 'diterima' && r.kontakWa != null)
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openWhatsApp(
                                      r.kontakWa,
                                      'Halo Pengelola ${r.warehouseNama}, pengajuan sewa ${formatKg(r.qtyKg)} telah disetujui.',
                                    ),
                                    icon: const Icon(Icons.chat_outlined, size: 16),
                                    label: const Text('WA'),
                                  ),
                                if (r.status == 'diajukan' || r.status == 'diterima')
                                  TextButton(
                                    onPressed: () async {
                                      await widget.appState.api.respondRental(r.id, 'batal');
                                      await _refreshAll();
                                    },
                                    child: const Text('Batal'),
                                  ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                    const Text('Penawaran Jual ke Pembeli',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (_sales.isEmpty)
                      const Text('Belum ada penawaran jual.',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ..._sales.map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text('${s.commodityNama} → ${s.buyerNama} (${formatKg(s.qtyKg)})'),
                            subtitle: Text(
                                'Tawar ${formatRupiah(s.hargaTawar)}/kg (Total ${formatRupiah(s.totalNilaiRp)}) · ${formatStatusLabel(s.status)}'),
                            trailing: (s.status == 'diajukan' || s.status == 'diterima')
                                ? TextButton(
                                    onPressed: () async {
                                      await widget.appState.api.respondSale(s.id, 'batal');
                                      await _refreshAll();
                                    },
                                    child: const Text('Batal'),
                                  )
                                : null,
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    final ctrl = TextEditingController(text: 'TANIJAYA');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gabung Kelompok Tani via Kode'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Kode Gabung 8 Karakter',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              try {
                await widget.appState.api
                    .joinGroup(widget.appState.currentUser!.id, ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                await _refreshAll();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Gabung'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupOrLotDialog() {
    final user = widget.appState.currentUser!;
    final leaderGroups = _groups.where((g) => g.isKetua).toList();
    if (leaderGroups.isEmpty) {
      final namaCtrl = TextEditingController(text: 'Poktan Harapan Makmur');
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buat Kelompok Tani Baru'),
          content: TextField(
            controller: namaCtrl,
            decoration:
                const InputDecoration(labelText: 'Nama Kelompok Tani', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                await widget.appState.api
                    .createGroup(user.id, user.nama, namaCtrl.text.trim(), user.kabupaten);
                if (ctx.mounted) Navigator.pop(ctx);
                await _refreshAll();
              },
              child: const Text('Buat Poktan'),
            ),
          ],
        ),
      );
      return;
    }

    var grpId = leaderGroups.first.id;
    var commKode = 'jagung';
    final targetCtrl = TextEditingController(text: '10000');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Lot Kolektif Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: grpId,
              decoration: const InputDecoration(labelText: 'Poktan', border: OutlineInputBorder()),
              items: leaderGroups
                  .map((g) => DropdownMenuItem(value: g.id, child: Text(g.nama)))
                  .toList(),
              onChanged: (v) => grpId = v ?? grpId,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: commKode,
              decoration:
                  const InputDecoration(labelText: 'Komoditas', border: OutlineInputBorder()),
              items: _commodities
                  .map((c) => DropdownMenuItem(value: c.kode, child: Text(c.nama)))
                  .toList(),
              onChanged: (v) => commKode = v ?? 'jagung',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Target Volume Lot (kg)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              await widget.appState.api
                  .createLot(grpId, commKode, double.tryParse(targetCtrl.text) ?? 10000);
              if (ctx.mounted) Navigator.pop(ctx);
              await _refreshAll();
            },
            child: const Text('Buat Lot'),
          ),
        ],
      ),
    );
  }

  void _showContributeLotDialog(LotItem lt) {
    final matching =
        _stocks.where((s) => s.freeKg > 0 && s.commodityKode == lt.commodityKode).toList();
    if (matching.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada stok bebas ${lt.commodityNama} untuk disumbangkan.')),
      );
      return;
    }
    var stId = matching.first.id;
    final qtyCtrl = TextEditingController(text: matching.first.freeKg.toStringAsFixed(0));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kontribusi Stok ke ${lt.groupNama}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: stId,
              decoration:
                  const InputDecoration(labelText: 'Pilih Stok Bebas', border: OutlineInputBorder()),
              items: matching
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.commodityNama} (${formatKg(s.freeKg)})'),
                      ))
                  .toList(),
              onChanged: (v) => stId = v ?? stId,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Jumlah Disumbangkan (kg)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final user = widget.appState.currentUser!;
              await widget.appState.api.contributeLot(
                user.id,
                user.nama,
                lt.id,
                stId,
                double.tryParse(qtyCtrl.text) ?? 0,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _refreshAll();
            },
            child: const Text('Simpan Kontribusi'),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String val, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Text(
              val,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: highlight ? const Color(0xFF047857) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
