import 'package:flutter/material.dart';
import '../core/app_state.dart';

Future<void> showServerConfigDialog(BuildContext context, AppState appState) async {
  final ctrl = TextEditingController(text: appState.api.baseUrl);
  var offline = appState.api.offlineFallbackMode;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Koneksi Backend Go Modular Monolith'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi Flutter terhubung ke Go Modular Monolith + Podman PostgreSQL. Bila diuji pada HP tanpa server lokal, aktifkan Mode Mandiri Offline.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'URL API Go Backend',
                  hintText: 'http://10.0.2.2:8080 atau http://localhost:8080',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Emulator Android (10.0.2.2)'),
                    onPressed: () => setState(() => ctrl.text = 'http://10.0.2.2:8080'),
                  ),
                  ActionChip(
                    label: const Text('Web / Desktop (localhost)'),
                    onPressed: () => setState(() => ctrl.text = 'http://localhost:8080'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode Simulasi Mandiri (Offline APK)'),
                subtitle: const Text('Tetap fungsional 100% saat tidak ada koneksi server'),
                value: offline,
                onChanged: (v) => setState(() => offline = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              await appState.updateServerConfig(url: ctrl.text, forceOffline: offline);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan & Uji Koneksi'),
          ),
        ],
      ),
    ),
  );
}
