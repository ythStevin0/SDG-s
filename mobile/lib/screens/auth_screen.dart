import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/theme.dart';
import '../widgets/server_config_dialog.dart';

class AuthScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onBackToLanding;

  const AuthScreen({
    super.key,
    required this.appState,
    required this.onBackToLanding,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  String _role = 'petani';
  String _kabupaten = 'Banyumas';

  static const _demoPersonas = [
    (
      preset: 'petani',
      title: 'Pak Slamet (Petani)',
      subtitle: 'Stok jagung 5 ton & gabah GKP basah 4 ton (KA 22%)',
      icon: Icons.agriculture_rounded,
    ),
    (
      preset: 'poktan',
      title: 'Bu Rini (Ketua Poktan)',
      subtitle: 'Poktan Tani Jaya, kode gabung TANIJAYA, Lot Kolektif 6 dari 10 ton',
      icon: Icons.groups_rounded,
    ),
    (
      preset: 'gudang',
      title: 'Pak Joko (Pengelola Gudang SRG)',
      subtitle: 'Kelola 4 gudang SRG & koperasi daerah serta persetujuan sewa atomik',
      icon: Icons.warehouse_rounded,
    ),
    (
      preset: 'pembeli',
      title: 'Koperasi & SPPG Mitra (Pembeli)',
      subtitle: 'Pasang kuota Janji Beli dan proses penawaran masuk petani',
      icon: Icons.storefront_rounded,
    ),
    (
      preset: 'admin',
      title: 'Admin SimpanJual',
      subtitle: 'Atur parameter komoditas JSONB dan pantau status pool server',
      icon: Icons.tune_rounded,
    ),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _runDemo(String preset) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.appState.loginWithDemo(preset);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitManual() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Mohon isi alamat email dan kata sandi terlebih dahulu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await widget.appState.registerAccount(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          nama: _namaCtrl.text.trim(),
          role: _role,
          kabupaten: _kabupaten,
        );
      } else {
        await widget.appState.loginManual(_emailCtrl.text.trim(), _passCtrl.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SimpanJualPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali ke panggung utama',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBackToLanding,
        ),
        title: const SimpanJualBrand(lightOnDark: true, compact: true),
        actions: [
          IconButton(
            tooltip: widget.appState.darkMode ? 'Mode Terang' : 'Mode Rimbun Gelap',
            onPressed: widget.appState.toggleDarkMode,
            icon: Icon(
              widget.appState.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: p.goldTextOnDark),
            onPressed: () => showServerConfigDialog(context, widget.appState),
            icon: const Icon(Icons.dns_outlined, size: 18),
            label: Text(widget.appState.api.offlineFallbackMode ? 'Offline' : 'Live Go API'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  StatePanel(
                    icon: Icons.error_outline_rounded,
                    title: 'Gagal memproses autentikasi',
                    message: _error!,
                    isError: true,
                  ),
                  const SizedBox(height: 16),
                ],
                ResponsiveThreeStageGrid(
                  maxColumns: 2,
                  spacing: 20,
                  children: [
                    // Kolom 1: Masuk Cepat 5 Akun Demo
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Masuk Cepat 5 Peran Demo',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: p.ink,
                                    ),
                                  ),
                                ),
                                const StampBadge(label: '1 KLIK', tone: StampTone.ok),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pilih salah satu akun simulasi di bawah untuk menguji alur penuh lintas peran (sandi manual bila diketik: demo12345).',
                              style: TextStyle(fontSize: 13, color: p.inkMuted, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            ..._demoPersonas.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _busy ? null : () => _runDemo(item.preset),
                                  child: Ink(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: p.surfaceAlt,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(6),
                                        bottomLeft: Radius.circular(6),
                                        bottomRight: Radius.circular(10),
                                      ),
                                      border: Border.all(color: p.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: p.frameBg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(item.icon, color: p.harvestGold, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: p.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.subtitle,
                                                style: TextStyle(fontSize: 12, color: p.inkMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_rounded, color: p.ink, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Kolom 2: Form Masuk / Registrasi Manual
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isRegister ? 'Pendaftaran Akun Baru' : 'Masuk dengan Email',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('Masuk Akun')),
                                ButtonSegment(value: true, label: Text('Daftar Baru')),
                              ],
                              selected: {_isRegister},
                              onSelectionChanged: (s) => setState(() => _isRegister = s.first),
                            ),
                            const SizedBox(height: 16),
                            if (_isRegister) ...[
                              TextField(
                                controller: _namaCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Lengkap / Poktan / Koperasi',
                                  hintText: 'Masukkan nama pengguna atau organisasi',
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _role,
                                decoration: const InputDecoration(labelText: 'Pilih Peran Akun'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'petani',
                                    child: Text('Petani / Pengurus Poktan'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'gudang',
                                    child: Text('Pengelola Gudang Penyimpanan'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pembeli',
                                    child: Text('Pembeli (Koperasi / RMU / SPPG)'),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _role = v ?? 'petani'),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _kabupaten,
                                decoration: const InputDecoration(labelText: 'Kabupaten Wilayah'),
                                items: SimpanJualEngine.jatengCoords.keys
                                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                                    .toList(),
                                onChanged: (v) => setState(() => _kabupaten = v ?? 'Banyumas'),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Alamat Email',
                                hintText: 'nama@domain.id',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Kata Sandi',
                                hintText: 'Minimal 6 karakter',
                              ),
                              onSubmitted: (_) => _submitManual(),
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SplitGoldCtaButton(
                                label: _busy
                                    ? 'Memproses Sesi...'
                                    : (_isRegister ? 'Buat Akun & Masuk' : 'Masuk Sekarang'),
                                onPressed: _busy ? null : _submitManual,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
