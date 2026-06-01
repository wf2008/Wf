import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'developer_capture_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _devKey = 'dev_mode_enabled';
  final _storage = const FlutterSecureStorage();
  int _tapCount = 0;
  bool _devMode = false;

  static const String whatsappUrl = 'https://wa.me/2348000000000?text=Hello%20Wfseek';
  static const String telegramUrl = 'https://t.me/YourTelegramUsername';
  static const String version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadDev();
  }

  Future<void> _loadDev() async {
    final v = await _storage.read(key: _devKey);
    if (mounted) setState(() => _devMode = v == 'true');
  }

  Future<void> _toggleDev() async {
    final next = !_devMode;
    await _storage.write(key: _devKey, value: next ? 'true' : 'false');
    if (mounted) setState(() => _devMode = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Developer mode ${next ? "ON" : "OFF"}')),
      );
    }
  }

  void _onVersionTap() {
    _tapCount++;
    if (_tapCount >= 7) {
      _tapCount = 0;
      _toggleDev();
    }
  }

  Future<void> _open(String u) async {
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('App Version'),
            subtitle: Text(version),
            onTap: _onVersionTap,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Contact Us',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('WhatsApp'),
            onTap: () => _open(whatsappUrl),
          ),
          ListTile(
            leading: const Icon(Icons.telegram, color: Colors.blue),
            title: const Text('Telegram'),
            onTap: () => _open(telegramUrl),
          ),
          const Divider(),
          if (_devMode)
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('API Capture'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DeveloperCaptureScreen())),
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () async {
              await AuthService().signOut();
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
