import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
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
      title: 'Pak Slamet — Petani',
      subtitle: 'Stok jagung 5 ton & gabah GKP basah 4 ton (KA 22%)',
      icon: Icons.agriculture_rounded,
      color: Color(0xFF047857),
    ),
    (
      preset: 'poktan',
      title: 'Bu Rini — Ketua Poktan',
      subtitle: 'Poktan Tani Jaya · Kode gabung TANIJAYA · Lot Kolektif 6/10 ton',
      icon: Icons.groups_rounded,
      color: Color(0xFF0F766E),
    ),
    (
      preset: 'gudang',
      title: 'Pak Joko — Pengelola Gudang SRG',
      subtitle: 'Kelola 4 gudang SRG & koperasi · Terima/tolak sewa atomik',
      icon: Icons.warehouse_rounded,
      color: Color(0xFF1D4ED8),
    ),
    (
      preset: 'pembeli',
      title: 'Koperasi & SPPG Mitra — Pembeli',
      subtitle: 'Pasang Janji Beli & serap pasokan petani lokal',
      icon: Icons.storefront_rounded,
      color: Color(0xFFB45309),
    ),
    (
      preset: 'admin',
      title: 'Admin SimpanJual',
      subtitle: 'Konfigurasi parameter JSONB komoditas & observabilitas server',
      icon: Icons.admin_panel_settings_rounded,
      color: Color(0xFF4338CA),
    ),
  ];

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBackToLanding,
        ),
        title: const Text('Masuk ke SimpanJual'),
        actions: [
          TextButton.icon(
            onPressed: () => showServerConfigDialog(context, widget.appState),
            icon: const Icon(Icons.dns_outlined, size: 18),
            label: Text(widget.appState.api.offlineFallbackMode ? 'Offline' : 'Live API'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
                  ),

                // Panel 1-Click Demo Login untuk Dewan Juri (F1)
                Card(
                  elevation: 0,
                  color: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: Color(0xFF047857)),
                            SizedBox(width: 6),
                            Text(
                              '1-Click Demo Login (Akses Cepat Dewan Juri)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ketuk salah satu peran di bawah untuk langsung menguji alur penuh lintas aktor (sandi manual: demo12345).',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF166534)),
                        ),
                        const SizedBox(height: 12),
                        ..._demoPersonas.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _busy ? null : () => _runDemo(p.preset),
                              child: Ink(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: p.color.withValues(alpha: 0.12),
                                      child: Icon(p.icon, color: p.color),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.title,
                                              style: const TextStyle(fontWeight: FontWeight.w800)),
                                          Text(p.subtitle,
                                              style: const TextStyle(
                                                  fontSize: 12, color: Color(0xFF475569))),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
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

                const SizedBox(height: 18),

                // Form Login / Registrasi Manual
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Masuk Email')),
                            ButtonSegment(value: true, label: Text('Daftar Akun Baru')),
                          ],
                          selected: {_isRegister},
                          onSelectionChanged: (s) => setState(() => _isRegister = s.first),
                        ),
                        const SizedBox(height: 14),
                        if (_isRegister) ...[
                          TextField(
                            controller: _namaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Lengkap / Kelompok / Organisasi',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            decoration: const InputDecoration(
                              labelText: 'Peran Akun',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'petani', child: Text('Petani / Pengurus Poktan')),
                              DropdownMenuItem(value: 'gudang', child: Text('Pengelola Gudang')),
                              DropdownMenuItem(value: 'pembeli', child: Text('Pembeli (Koperasi / SPPG / Pabrik)')),
                            ],
                            onChanged: (v) => setState(() => _role = v ?? 'petani'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _kabupaten,
                            decoration: const InputDecoration(
                              labelText: 'Kabupaten',
                              border: OutlineInputBorder(),
                            ),
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
                            labelText: 'Email',
                            hintText: 'petani@demo.id',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Kata Sandi',
                            hintText: 'demo12345',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: _busy ? null : _submitManual,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isRegister ? 'Daftar & Masuk' : 'Masuk'),
                        ),
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
}
