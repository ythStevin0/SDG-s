import 'package:flutter/material.dart';
import '../core/app_state.dart';

Future<void> showServerConfigDialog(BuildContext context, AppState appState) async {
  final ctrl = TextEditingController(text: appState.api.baseUrl);
  var offline = appState.api.offlineFallbackMode;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Koneksi Server Backend Go'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi terhubung ke API Go Modular Monolith dan PostgreSQL Podman. Jika menguji APK tanpa server lokal, aktifkan Mode Simulasi Mandiri.',
                style: TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Alamat URL API Backend',
                  hintText: 'Contoh: http://10.0.2.2:8080',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => ctrl.text = 'http://10.0.2.2:8080'),
                    child: const Text('Emulator Android (10.0.2.2)'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => ctrl.text = 'http://localhost:8080'),
                    child: const Text('Web / Desktop (localhost)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode Simulasi Mandiri (Tanpa Server)'),
                subtitle: const Text('Menjalankan mesin hitung Dart secara lokal di perangkat'),
                value: offline,
                onChanged: (v) => setState(() => offline = v),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await appState.updateServerConfig(url: ctrl.text, forceOffline: offline);
              if (ctx.mounted) nav.pop();
            },
            child: const Text('Simpan Koneksi'),
          ),
        ],
      ),
    ),
  );
}
