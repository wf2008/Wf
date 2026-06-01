import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/capture_interceptor.dart';

class DeveloperCaptureScreen extends StatefulWidget {
  const DeveloperCaptureScreen({super.key});
  @override
  State<DeveloperCaptureScreen> createState() => _DeveloperCaptureScreenState();
}

class _DeveloperCaptureScreenState extends State<DeveloperCaptureScreen> {
  final _url = TextEditingController(text: 'https://');
  final List<Map<String, dynamic>> _captures = [];
  bool _capturing = false;

  Future<void> _startCapture() async {
    if (_url.text.isEmpty) return;
    setState(() => _capturing = true);

    // Declare first so the NavigationDelegate callbacks can capture it.
    final controller = WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.addJavaScriptChannel(
      'CaptureChannel',
      onMessageReceived: (msg) {
        try {
          final entry = jsonDecode(msg.message) as Map<String, dynamic>;
          setState(() => _captures.add(entry));
        } catch (_) {}
      },
    );
    controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) async {
        try {
          await _runJs(controller, captureJS);
        } catch (_) {}
      },
      onPageFinished: (_) async {
        try {
          await _runJs(controller, captureJS);
        } catch (_) {}
      },
    ));
    controller.loadRequest(Uri.parse(_url.text));

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(Uri.parse(_url.text).host)),
        body: WebViewWidget(controller: controller),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.stop),
          label: const Text('Stop Capture'),
        ),
      ),
    ));

    if (mounted) setState(() => _capturing = false);
  }

  Future<void> _runJs(WebViewController c, String code) async {
    await c.runJavaScript(code);
  }

  Future<void> _export() async {
    final dir = await getTemporaryDirectory();
    final host = Uri.tryParse(_url.text)?.host ?? 'capture';
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/captured_${host}_$ts.json');
    await file.writeAsString(jsonEncode(_captures));
    await Share.shareXFiles([XFile(file.path)], text: 'Wfseek capture');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear',
            onPressed: () => setState(_captures.clear),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export JSON',
            onPressed: _captures.isEmpty ? null : _export,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _capturing ? null : _startCapture,
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _captures.length,
              itemBuilder: (ctx, i) {
                final c = _captures[i];
                return ListTile(
                  dense: true,
                  title: Text('${c['method']} ${c['url']}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('status=${c['status']} • ${c['type']}'),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Capture detail'),
                      content: SingleChildScrollView(
                        child: Text(const JsonEncoder.withIndent('  ')
                            .convert(c)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
