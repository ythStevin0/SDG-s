import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/formatters.dart';
import '../core/models.dart';
import '../core/theme.dart';
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
  bool _sidebarExpanded = true;
  bool _loading = true;
  String? _loadError;

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
    setState(() {
      _loading = true;
      _loadError = null;
    });
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
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
    final qtyCtrl = TextEditingController();
    final kaCtrl = TextEditingController();
    final catatanCtrl = TextEditingController();
    var kab = user.kabupaten;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setModal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Catat Stok Panen Baru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: kode,
                  decoration: const InputDecoration(labelText: 'Pilih Komoditas'),
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
                    labelText: 'Berat Panen (kg)',
                    hintText: 'Contoh: 3500',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Kadar Air Aktual (%)',
                    hintText: 'Contoh: 16.5',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: SimpanJualEngine.jatengCoords.containsKey(kab) ? kab : 'Banyumas',
                  decoration: const InputDecoration(labelText: 'Kabupaten Lokasi Panen'),
                  items: SimpanJualEngine.jatengCoords.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setModal(() => kab = v ?? 'Banyumas'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catatanCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Blok Sawah / Mutu',
                    hintText: 'Opsional, misal blok sawah utara',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(ctx);
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
                    if (ctx.mounted) nav.pop();
                    await _refreshAll();
                  },
                  child: const Text('Simpan Catatan Stok'),
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
          title: Text('Ajukan Sewa Ruang: ${wh.nama}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Minimum ${formatKg(wh.minVolumeKg)} • Minimum ${wh.minHari} hari • Tarif Rp${wh.tarifPerKgHari}/kg/hari',
                  style: const TextStyle(fontSize: 12.5),
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
                    decoration: const InputDecoration(labelText: 'Pilih Stok Bebas'),
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
                    decoration: const InputDecoration(labelText: 'Pilih Lot Kolektif'),
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
                  decoration: const InputDecoration(labelText: 'Volume Diajukan (kg)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hariCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Lama Simpan (hari)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final rootMessenger = ScaffoldMessenger.of(context);
                final dialogMessenger = ScaffoldMessenger.of(ctx);
                final nav = Navigator.of(ctx);
                try {
                  await widget.appState.api.submitRental(widget.appState.currentUser!, {
                    if (!useLot) 'stockId': selectedStockId,
                    if (useLot) 'lotId': selectedLotId,
                    'warehouseId': wh.id,
                    'qtyKg': double.tryParse(qtyCtrl.text) ?? 0,
                    'hari': int.tryParse(hariCtrl.text) ?? 30,
                  });
                  if (ctx.mounted) nav.pop();
                  await _refreshAll();
                  if (mounted) {
                    rootMessenger.showSnackBar(
                      const SnackBar(content: Text('Pengajuan sewa berhasil dikirim secara atomik.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    dialogMessenger.showSnackBar(
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
        SnackBar(content: Text('Belum ada stok bebas ${dem.commodityNama} yang dapat ditawarkan.')),
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
                'Sisa kuota pembeli: ${formatKg(dem.sisaKuotaKg)} • Harga acuan ${formatRupiah(dem.hargaAcuan)}/kg',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: stockId,
                decoration: const InputDecoration(labelText: 'Pilih Stok Bebas'),
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
                decoration: const InputDecoration(labelText: 'Volume Ditawarkan (kg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tawarCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga Tawar (Rp/kg)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final rootMessenger = ScaffoldMessenger.of(context);
                final dialogMessenger = ScaffoldMessenger.of(ctx);
                final nav = Navigator.of(ctx);
                try {
                  await widget.appState.api.submitSale(widget.appState.currentUser!, {
                    'stockId': stockId,
                    'demandId': dem.id,
                    'qtyKg': double.tryParse(qtyCtrl.text) ?? 0,
                    'hargaTawar': int.tryParse(tawarCtrl.text) ?? dem.hargaAcuan,
                  });
                  if (ctx.mounted) nav.pop();
                  await _refreshAll();
                  if (mounted) {
                    rootMessenger.showSnackBar(
                      const SnackBar(content: Text('Penawaran jual berhasil diajukan.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    dialogMessenger.showSnackBar(
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
    final p = SimpanJualPalette.of(context);
    final user = widget.appState.currentUser!;
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1024;
    final isTablet = w >= 640 && w < 1024;

    final mainContent = _loading
        ? const Padding(
            padding: EdgeInsets.all(20),
            child: StatePanel(
              icon: Icons.sync_rounded,
              title: 'Memuat data panen, gudang, dan bursa pembeli',
              message: 'Menyinkronkan stok bebas dan status pengajuan terkini.',
              isLoading: true,
            ),
          )
        : _loadError != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: StatePanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Gagal memuat data ruang kerja petani',
                  message: _loadError!,
                  actionLabel: 'Muat Ulang Data',
                  onAction: _refreshAll,
                  isError: true,
                ),
              )
            : IndexedStack(
                index: _navIndex,
                children: [
                  _buildStokDanHargaTab(p),
                  _buildSimpanDanLotTab(p),
                  _buildJualDanRiwayatTab(p),
                ],
              );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SimpanJualBrand(lightOnDark: true, compact: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${user.nama} (${user.kabupaten})',
                style: TextStyle(fontSize: 13.5, color: p.goldTextOnDark, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.appState.darkMode ? 'Mode Terang' : 'Mode Rimbun Gelap',
            onPressed: widget.appState.toggleDarkMode,
            icon: Icon(
              widget.appState.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Perbesar Teks Mode Lapangan Aa+',
            onPressed: widget.appState.toggleFieldMode,
            icon: const Icon(Icons.format_size_rounded),
          ),
          IconButton(
            tooltip: 'Pengaturan Server',
            onPressed: () => showServerConfigDialog(context, widget.appState),
            icon: Icon(
              widget.appState.api.offlineFallbackMode
                  ? Icons.portable_wifi_off_outlined
                  : Icons.dns_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Muat Ulang Data',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Keluar / Ganti Akun Peran',
            onPressed: widget.appState.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: _navIndex == 0
          ? SplitGoldCtaButton(
              label: 'Catat Stok Panen',
              onPressed: _showAddStockSheet,
            )
          : null,
      bottomNavigationBar: (!isDesktop && !isTablet)
          ? SafeArea(
              top: false,
              child: NavigationBar(
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
            )
          : null,
      body: isDesktop
          ? Row(
              children: [
                _buildDesignedDesktopSidebar(p),
                Expanded(child: mainContent),
              ],
            )
          : isTablet
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: p.frameBg,
                      selectedIndex: _navIndex,
                      indicatorColor: p.harvestGold,
                      selectedIconTheme: IconThemeData(color: p.onGold),
                      unselectedIconTheme: const IconThemeData(color: Color(0xFFC2D6C4)),
                      selectedLabelTextStyle:
                          TextStyle(color: p.goldTextOnDark, fontWeight: FontWeight.w800),
                      unselectedLabelTextStyle: const TextStyle(color: Color(0xFFC2D6C4)),
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
                    Expanded(child: mainContent),
                  ],
                )
              : mainContent,
    );
  }

  Widget _buildDesignedDesktopSidebar(SimpanJualPalette p) {
    const items = [
      (icon: Icons.inventory_2_rounded, label: 'Stok & Proyeksi Harga'),
      (icon: Icons.warehouse_rounded, label: 'Gudang SRG & Lot Poktan'),
      (icon: Icons.storefront_rounded, label: 'Janji Beli & Riwayat'),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _sidebarExpanded ? 248 : 76,
      color: p.frameBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              mainAxisAlignment:
                  _sidebarExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                if (_sidebarExpanded)
                  Text(
                    'MENU PETANI',
                    style: TextStyle(
                      color: p.goldTextOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                IconButton(
                  tooltip: _sidebarExpanded ? 'Ciutkan bilah menu' : 'Bentangkan bilah menu',
                  onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                  icon: Icon(
                    _sidebarExpanded
                        ? Icons.keyboard_double_arrow_left_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Semantics(
                button: true,
                selected: _navIndex == i,
                label: items[i].label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _navIndex = i),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _navIndex == i ? p.harvestGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          _sidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          color: _navIndex == i ? p.onGold : const Color(0xFFC2D6C4),
                          size: 20,
                        ),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              items[i].label,
                              style: TextStyle(
                                color: _navIndex == i ? p.onGold : Colors.white,
                                fontWeight: _navIndex == i ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (_sidebarExpanded)
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.stageLeft,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Text(
                'Stok aktif: ${_stocks.length} lot panen\nKode poktan demo: TANIJAYA',
                style: const TextStyle(color: Color(0xFFC2D6C4), fontSize: 12, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStokDanHargaTab(SimpanJualPalette p) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
        children: [
          // Banner ringkas beraksen lengkung emas sesuai identitas visual
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.stageLeft, p.stageMid],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LUMBUNG STOK PETANI',
                        style: TextStyle(
                          color: p.goldTextOnDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih stok panen untuk menghitung titik impas tahan gudang atau adu panjar.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_stocks.isEmpty)
            StatePanel(
              icon: Icons.inventory_2_outlined,
              title: 'Belum ada catatan stok panen',
              message:
                  'Tambahkan stok gabah atau jagung Anda terlebih dahulu untuk membuka kalkulator titik impas dan pencarian gudang.',
              actionLabel: 'Catat Stok Pertama',
              onAction: _showAddStockSheet,
            )
          else
            ResponsiveThreeStageGrid(
              maxColumns: 2,
              children: _stocks.map((st) {
                final perluJemur = st.kadarAir > st.commodityParams.kadarAirMaksPct;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                st.commodityNama,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: p.ink,
                                ),
                              ),
                            ),
                            StampBadge(
                              label: formatStatusLabel(st.status),
                              tone: st.freeKg > 0 ? StampTone.ok : StampTone.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Panen ${st.tglPanen} • ${st.kabupaten}',
                          style: TextStyle(fontSize: 12.5, color: p.inkMuted),
                        ),
                        const Divider(height: 18),
                        LedgerRow(label: 'Total panen tercatat', value: formatKg(st.qtyKg)),
                        LedgerRow(label: 'Terkunci pada sewa/lot', value: formatKg(st.reservedKg)),
                        LedgerRow(
                          label: 'Stok bebas siap alokasi',
                          value: formatKg(st.freeKg),
                          emphasize: true,
                          valueColor: p.okInk,
                        ),
                        LedgerRow(
                          label: 'Kadar air aktual',
                          value: perluJemur
                              ? '${st.kadarAir}% (Jemur ke ≤${st.commodityParams.kadarAirMaksPct}%)'
                              : '${st.kadarAir}% (Siap simpan)',
                          valueColor: perluJemur ? p.warnInk : p.okInk,
                        ),
                        const SizedBox(height: 14),
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
                                icon: const Icon(Icons.calculate_outlined, size: 18),
                                label: const Text('Buka Hitungan Keputusan'),
                              ),
                            ),
                            if (st.reservedKg == 0 && st.soldKg == 0) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Hapus catatan stok ini',
                                onPressed: () async {
                                  await widget.appState.api.deleteStock(st.id);
                                  await _refreshAll();
                                },
                                icon: Icon(Icons.delete_outline_rounded, color: p.dangerInk),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Bagaimana arah harga $_selectedPriceComm dalam 4 sampai 12 minggu ke depan?',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: p.ink),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                  Text(
                    'Harga acuan terkini: ${formatRupiah(_latestPrice)}/kg (Data ilustrasi Jawa Tengah)',
                    style: TextStyle(fontSize: 13, color: p.inkMuted),
                  ),
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

  Widget _buildSimpanDanLotTab(SimpanJualPalette p) {
    final user = widget.appState.currentUser!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: p.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Peta & Skor Gudang'),
                Tab(text: 'Lot Kolektif Poktan'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: _commodities.any((c) => c.kode == _whFilterComm)
                              ? _whFilterComm
                              : 'jagung',
                          items: _commodities
                              .map((c) => DropdownMenuItem(
                                    value: c.kode,
                                    child: Text('Komoditas: ${c.nama}'),
                                  ))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _whFilterComm = v);
                            await _refreshAll();
                          },
                        ),
                        FilterChip(
                          label: const Text('Khusus Gudang SRG'),
                          selected: _onlySrg,
                          onSelected: (v) async {
                            setState(() => _onlySrg = v);
                            await _refreshAll();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WarehouseMapCard(
                      farmerKabupaten: user.kabupaten,
                      warehouses: _warehouses,
                      onSelectWarehouse: (wh) {
                        if (wh.score.isEligible) _showRentalDialog(wh);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_warehouses.isEmpty)
                      const StatePanel(
                        icon: Icons.warehouse_outlined,
                        title: 'Tidak ada gudang yang cocok dengan saringan ini',
                        message: 'Matikan filter Khusus Gudang SRG atau ganti komoditas.',
                      )
                    else
                      ResponsiveThreeStageGrid(
                        maxColumns: 2,
                        children: _warehouses.map((wh) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: p.ink,
                                          ),
                                        ),
                                      ),
                                      StampBadge(
                                        label: wh.score.isEligible
                                            ? 'SKOR ${wh.score.totalScore}/100'
                                            : 'TIDAK MEMENUHI',
                                        tone: wh.score.isEligible ? StampTone.ok : StampTone.warn,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LedgerRow(
                                    label: 'Lokasi & estimasi jarak jalan',
                                    value: '${wh.kabupaten} (~${wh.score.distanceKm} km)',
                                  ),
                                  LedgerRow(
                                    label: 'Sisa ruang tersedia',
                                    value: formatKg(wh.tersediaKg),
                                    emphasize: true,
                                  ),
                                  LedgerRow(
                                    label: 'Tarif simpan harian',
                                    value: 'Rp${wh.tarifPerKgHari}/kg/hari',
                                  ),
                                  if (!wh.score.isEligible && wh.score.ineligibleReason != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Kendala: ${wh.score.ineligibleReason}',
                                        style: TextStyle(
                                          color: p.dangerInk,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  else ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sub-skor: Fasilitas ${wh.score.fasilitasWajib}/30 • Kondisi/SRG ${wh.score.kondisiDanSrg}/30 • Jarak ${wh.score.jarak}/15 • Tarif ${wh.score.tarif}/15 • Ruang ${wh.score.kapasitas}/10',
                                      style: TextStyle(fontSize: 12, color: p.inkMuted),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: () => _showRentalDialog(wh),
                                      icon: const Icon(Icons.lock_clock_outlined, size: 18),
                                      label: const Text('Ajukan Sewa Ruang'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),

                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showJoinGroupDialog,
                          icon: const Icon(Icons.group_add_outlined),
                          label: const Text('Gabung Kode Poktan'),
                        ),
                        FilledButton.icon(
                          onPressed: _showCreateGroupOrLotDialog,
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Buat Poktan / Lot Baru'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_groups.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _groups
                            .map((g) => StampBadge(
                                  label: '${g.nama} • KODE: ${g.kodeGabung}',
                                  icon: Icons.groups_rounded,
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 14),
                    if (_lots.isEmpty)
                      StatePanel(
                        icon: Icons.groups_outlined,
                        title: 'Belum tergabung pada Lot Kolektif',
                        message:
                            'Masukkan kode gabung TANIJAYA untuk ikut menghimpun stok bersama kelompok tani.',
                        actionLabel: 'Masukkan Kode Poktan',
                        onAction: _showJoinGroupDialog,
                      )
                    else
                      ..._lots.map((lt) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${lt.groupNama}: Lot ${lt.commodityNama}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: p.ink,
                                            ),
                                          ),
                                        ),
                                        StampBadge(
                                          label: formatStatusLabel(lt.status),
                                          tone: lt.status == 'siap_ajukan'
                                              ? StampTone.ok
                                              : StampTone.neutral,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LedgerRow(
                                      label: 'Progres volume terkumpul',
                                      value:
                                          '${formatKg(lt.terkumpulKg)} / ${formatKg(lt.targetKg)} (${lt.progressPct}%)',
                                      emphasize: true,
                                    ),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: (lt.progressPct / 100.0).clamp(0.0, 1.0),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 10),
                                    ...lt.contributions.map((c) => Text(
                                          '- ${c.userNama}: ${formatKg(c.qtyKg)} (${c.sharePct}% porsi)',
                                          style: TextStyle(fontSize: 13, color: p.inkMuted),
                                        )),
                                    const SizedBox(height: 12),
                                    if (lt.status == 'mengumpulkan' || lt.status == 'siap_ajukan')
                                      FilledButton.icon(
                                        onPressed: () => _showContributeLotDialog(lt),
                                        icon: const Icon(Icons.merge_type_rounded),
                                        label: const Text('Sumbang Stok Bebas ke Lot Ini'),
                                      ),
                                  ],
                                ),
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

  Widget _buildJualDanRiwayatTab(SimpanJualPalette p) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: p.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Bursa Janji Beli'),
                Tab(text: 'Status Sewa & Jual'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                  children: [
                    if (_demands.isEmpty)
                      const StatePanel(
                        icon: Icons.storefront_outlined,
                        title: 'Belum ada pengumuman Janji Beli aktif',
                        message: 'Kebutuhan pasokan baru dari koperasi dan SPPG akan tampil di sini.',
                      )
                    else
                      ResponsiveThreeStageGrid(
                        maxColumns: 2,
                        children: _demands.map((d) {
                          final hasMatch = _stocks
                              .any((s) => s.freeKg > 0 && s.commodityKode == d.commodityKode);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${d.commodityNama}: ${d.buyerNama}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: p.ink,
                                          ),
                                        ),
                                      ),
                                      StampBadge(
                                        label: '${formatRupiah(d.hargaAcuan)}/kg',
                                        tone: StampTone.warn,
                                        icon: Icons.payments_outlined,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LedgerRow(label: 'Wilayah serah terima', value: d.kabupaten),
                                  LedgerRow(label: 'Batas waktu butuh', value: d.dibutuhkanPada),
                                  LedgerRow(
                                    label: 'Sisa kuota belum terpenuhi',
                                    value: formatKg(d.sisaKuotaKg),
                                    emphasize: true,
                                  ),
                                  if (d.catatanMutu != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Syarat mutu: ${d.catatanMutu}',
                                        style: TextStyle(fontSize: 12.5, color: p.inkMuted),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: (d.progressPct / 100.0).clamp(0.0, 1.0),
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (hasMatch)
                                        const StampBadge(
                                          label: 'COCOK DENGAN STOK ANDA',
                                          tone: StampTone.ok,
                                        ),
                                      FilledButton(
                                        onPressed: () => _showSaleDialog(d),
                                        child: const Text('Ajukan Penawaran Jual'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),

                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                  children: [
                    Text('Pengajuan Sewa Gudang',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    if (_rentals.isEmpty)
                      StatePanel(
                        icon: Icons.warehouse_outlined,
                        title: 'Belum ada pengajuan sewa ruang simpan',
                        message:
                            'Buka tab Simpan & Lot untuk memilih gudang SRG atau koperasi terdekat.',
                        actionLabel: 'Cari Gudang Simpan',
                        onAction: () => setState(() => _navIndex = 1),
                      )
                    else
                      ..._rentals.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                title: Text(
                                  '${r.warehouseNama} (${formatKg(r.qtyKg)} • ${r.hari} hari)',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  'Estimasi sewa ${formatRupiah(r.estimasiBiaya)} • Status: ${formatStatusLabel(r.status)}',
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    if (r.status == 'diterima' && r.kontakWa != null)
                                      FilledButton.tonalIcon(
                                        onPressed: () => _openWhatsApp(
                                          r.kontakWa,
                                          'Halo Pengelola ${r.warehouseNama}, pengajuan sewa ${formatKg(r.qtyKg)} telah disetujui.',
                                        ),
                                        icon: const Icon(Icons.chat_outlined, size: 16),
                                        label: const Text('WhatsApp'),
                                      ),
                                    if (r.status == 'diajukan' || r.status == 'diterima')
                                      OutlinedButton(
                                        onPressed: () async {
                                          await widget.appState.api.respondRental(r.id, 'batal');
                                          await _refreshAll();
                                        },
                                        child: const Text('Batalkan'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    const SizedBox(height: 20),
                    Text('Penawaran Jual ke Pembeli Siaga',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: p.ink)),
                    const SizedBox(height: 10),
                    if (_sales.isEmpty)
                      const StatePanel(
                        icon: Icons.handshake_outlined,
                        title: 'Belum ada penawaran jual aktif',
                        message: 'Pilih salah satu kebutuhan pembeli di tab Bursa Janji Beli.',
                      )
                    else
                      ..._sales.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                title: Text(
                                  '${s.commodityNama} ke ${s.buyerNama} (${formatKg(s.qtyKg)})',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  'Tawar ${formatRupiah(s.hargaTawar)}/kg (Total ${formatRupiah(s.totalNilaiRp)}) • ${formatStatusLabel(s.status)}',
                                ),
                                trailing: (s.status == 'diajukan' || s.status == 'diterima')
                                    ? OutlinedButton(
                                        onPressed: () async {
                                          await widget.appState.api.respondSale(s.id, 'batal');
                                          await _refreshAll();
                                        },
                                        child: const Text('Batalkan'),
                                      )
                                    : null,
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

  void _showJoinGroupDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gabung Kelompok Tani via Kode'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Kode Gabung 8 Karakter',
            hintText: 'Contoh demo: TANIJAYA',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final msg = ScaffoldMessenger.of(ctx);
              try {
                final code = ctrl.text.trim().isEmpty ? 'TANIJAYA' : ctrl.text.trim();
                await widget.appState.api.joinGroup(widget.appState.currentUser!.id, code);
                if (ctx.mounted) nav.pop();
                await _refreshAll();
              } catch (e) {
                if (ctx.mounted) {
                  msg.showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Gabung Poktan'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupOrLotDialog() {
    final user = widget.appState.currentUser!;
    final leaderGroups = _groups.where((g) => g.isKetua).toList();
    if (leaderGroups.isEmpty) {
      final namaCtrl = TextEditingController();
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buat Kelompok Tani Baru'),
          content: TextField(
            controller: namaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Kelompok Tani',
              hintText: 'Contoh: Poktan Sri Rejeki',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final name =
                    namaCtrl.text.trim().isEmpty ? 'Poktan Harapan Tani' : namaCtrl.text.trim();
                await widget.appState.api.createGroup(user.id, user.nama, name, user.kabupaten);
                if (ctx.mounted) nav.pop();
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
              decoration: const InputDecoration(labelText: 'Pilih Poktan'),
              items: leaderGroups
                  .map((g) => DropdownMenuItem(value: g.id, child: Text(g.nama)))
                  .toList(),
              onChanged: (v) => grpId = v ?? grpId,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: commKode,
              decoration: const InputDecoration(labelText: 'Komoditas Lot'),
              items: _commodities
                  .map((c) => DropdownMenuItem(value: c.kode, child: Text(c.nama)))
                  .toList(),
              onChanged: (v) => commKode = v ?? 'jagung',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Volume Lot (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await widget.appState.api
                  .createLot(grpId, commKode, double.tryParse(targetCtrl.text) ?? 10000);
              if (ctx.mounted) nav.pop();
              await _refreshAll();
            },
            child: const Text('Simpan Lot'),
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
              decoration: const InputDecoration(labelText: 'Pilih Stok Bebas'),
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
              decoration: const InputDecoration(labelText: 'Berat Disumbangkan (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final user = widget.appState.currentUser!;
              await widget.appState.api.contributeLot(
                user.id,
                user.nama,
                lt.id,
                stId,
                double.tryParse(qtyCtrl.text) ?? 0,
              );
              if (ctx.mounted) nav.pop();
              await _refreshAll();
            },
            child: const Text('Simpan Kontribusi'),
          ),
        ],
      ),
    );
  }
}
