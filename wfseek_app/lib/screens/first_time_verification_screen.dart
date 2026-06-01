import 'package:flutter/material.dart';
import '../scrapers/config.dart';
import '../services/cookie_manager.dart';

class FirstTimeVerificationScreen extends StatefulWidget {
  final VoidCallback onAllVerified;
  const FirstTimeVerificationScreen({super.key, required this.onAllVerified});

  @override
  State<FirstTimeVerificationScreen> createState() =>
      _FirstTimeVerificationScreenState();
}

class _FirstTimeVerificationScreenState
    extends State<FirstTimeVerificationScreen> {
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

  bool get _allVerified =>
      bookmakers.where((b) => b.protected).every((b) => _status[b.id] == true);

  Future<void> _verify(BookmakerConfig b) async {
    setState(() => _busy = true);
    await _cm.harvestCookies(context, b.baseUrl, showWebView: true);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = bookmakers.where((b) => b.protected).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Bookmakers'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'For security, we need to harvest cookies from each protected bookmaker. '
              'Solve any CAPTCHA or Cloudflare challenge that appears, then tap ✓.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final b = list[i];
                final ok = _status[b.id] == true;
                return ListTile(
                  title: Text(b.name),
                  subtitle: Text(b.domain),
                  trailing: ok
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: _busy ? null : () => _verify(b),
                          child: const Text('Verify now'),
                        ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _allVerified ? widget.onAllVerified : null,
                child: Text(_allVerified
                    ? 'Continue'
                    : 'Verify all bookmakers above'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
