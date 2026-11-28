import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  late final ApiClient api;
  final FlutterTts _tts = FlutterTts();

  UserProfile? currentUser;
  bool fieldMode = false;
  bool darkMode = false;
  bool isSpeaking = false;
  bool initialized = false;

  AppState() {
    api = ApiClient(baseUrl: ApiClient.defaultBaseUrl());
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        api.baseUrl = savedUrl;
      }
      fieldMode = prefs.getBool('field_mode') ?? false;
      darkMode = prefs.getBool('dark_mode') ?? false;
      final savedToken = prefs.getString('session_token');
      if (savedToken != null && savedToken.isNotEmpty && !savedToken.startsWith('offline-')) {
        api.token = savedToken;
        try {
          final me = await api.getJson('/api/v1/auth/me');
          currentUser = UserProfile.fromJson((me['user'] as Map).cast<String, dynamic>());
        } catch (_) {
          api.token = null;
        }
      }
      await api.checkHealth();
    } catch (_) {}

    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.47);
      _tts.setCompletionHandler(() {
        isSpeaking = false;
        notifyListeners();
      });
    } catch (_) {}

    initialized = true;
    notifyListeners();
  }

  Future<void> toggleFieldMode() async {
    fieldMode = !fieldMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('field_mode', fieldMode);
    } catch (_) {}
  }

  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', darkMode);
    } catch (_) {}
  }

  Future<void> updateServerConfig({required String url, required bool forceOffline}) async {
    api.baseUrl = url.trim();
    api.offlineFallbackMode = forceOffline;
    if (!forceOffline) {
      await api.checkHealth();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_base_url', api.baseUrl);
    } catch (_) {}
  }

  Future<void> loginWithDemo(String preset) async {
    final res = await api.demoLogin(preset);
    currentUser = res.user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', res.token);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loginManual(String email, String password) async {
    final res = await api.login(email, password);
    currentUser = res.user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', res.token);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> registerAccount({
    required String email,
    required String password,
    required String nama,
    required String role,
    required String kabupaten,
  }) async {
    final res = await api.register(
      email: email,
      password: password,
      nama: nama,
      role: role,
      kabupaten: kabupaten,
    );
    currentUser = res.user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', res.token);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    await stopSpeaking();
    currentUser = null;
    api.token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> speakText(String text) async {
    try {
      if (isSpeaking) {
        await _tts.stop();
        isSpeaking = false;
        notifyListeners();
        return;
      }
      isSpeaking = true;
      notifyListeners();
      await _tts.setLanguage('id-ID');
      await _tts.speak(text);
    } catch (_) {
      isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking = false;
  }
}
