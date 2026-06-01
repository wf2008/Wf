import 'package:flutter/material.dart';
import '../scrapers/config.dart';
import '../services/cookie_manager.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _cm = CookieManager();
  final Map<String, bool> _status = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    for (final b in bookmakers.where((b) => b.protected)) {
      _status[b.id] = await _cm.hasCookiesForDomain(b.domain);
    }
    if (mounted) setState(() {});
  }

  Future<void> _verify(BookmakerConfig b) async {
    setState(() => _busy = true);
    await _cm.harvestCookies(context, b.baseUrl, showWebView: true);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clear(BookmakerConfig b) async {
    await _cm.clearCookiesForDomain(b.domain);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final list = bookmakers.where((b) => b.protected).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final b = list[i];
          final ok = _status[b.id] == true;
          return ListTile(
            title: Text(b.name),
            subtitle: Text(ok ? 'Verified' : 'Needs verification'),
            leading: Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? Colors.green : Colors.orange,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ok)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _clear(b),
                    tooltip: 'Clear cookies',
                  ),
                TextButton(
                  onPressed: _busy ? null : () => _verify(b),
                  child: Text(ok ? 'Re-verify' : 'Verify now'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
