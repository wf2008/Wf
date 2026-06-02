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
        SnackBar(content: Text('Developer mode ${next ? "enabled" : "disabled"}')),
      );
    }
  }

  void _onVersionTap() {
    _tapCount++;
    if (_tapCount >= 7) { _tapCount = 0; _toggleDev(); }
  }

  Future<void> _open(String u) async {
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── App info card ────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up, color: Color(0xFF00897B), size: 22),
                ),
                title: const Text('Wfseek', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Version $version', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                trailing: Icon(Icons.info_outline, color: Colors.grey.shade400),
                onTap: _onVersionTap,
              ),
            ],
          ),

          _sectionLabel('Contact Us'),

          // ── Contact card ─────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF43A047), size: 22),
                ),
                title: const Text('WhatsApp Support', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chat with us directly'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _open(whatsappUrl),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send, color: Color(0xFF1976D2), size: 22),
                ),
                title: const Text('Telegram', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Join our channel'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _open(telegramUrl),
              ),
            ],
          ),

          if (_devMode) ...[
            _sectionLabel('Developer'),
            _SectionCard(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bug_report, color: Color(0xFFF57F17), size: 22),
                  ),
                  title: const Text('API Capture', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Inspect network requests'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeveloperCaptureScreen())),
                ),
              ],
            ),
          ],

          _sectionLabel('Account'),

          _SectionCard(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: Color(0xFFD32F2F), size: 22),
                ),
                title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD32F2F))),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await AuthService().signOut();
                    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 40),
          Center(
            child: Text('Tap version 7 times to toggle developer mode',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.grey.shade500, letterSpacing: 1)),
  );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}
