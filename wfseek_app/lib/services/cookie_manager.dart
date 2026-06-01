import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Manages cookie & User-Agent harvesting from bookmaker sites via WebView.
class CookieManager {
  static final CookieManager _instance = CookieManager._internal();
  factory CookieManager() => _instance;
  CookieManager._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _uaKey = 'global_user_agent';

  Future<bool> hasCookiesForDomain(String domain) async {
    final v = await _storage.read(key: 'cookies_$domain');
    return v != null && v.isNotEmpty;
  }

  Future<String?> getCookies(String domain) =>
      _storage.read(key: 'cookies_$domain');

  Future<Map<String, String>> getCookieHeader(String domain) async {
    final v = await _storage.read(key: 'cookies_$domain');
    if (v == null || v.isEmpty) return {};
    return {'Cookie': v};
  }

  Future<void> clearCookiesForDomain(String domain) =>
      _storage.delete(key: 'cookies_$domain');

  Future<String?> getUserAgent() => _storage.read(key: _uaKey);

  /// Harvests cookies & user agent for [url].
  /// [showWebView] = true → full-screen WebView so the user can solve CAPTCHA / Cloudflare.
  /// Includes one automatic retry with showWebView=true on failure.
  Future<bool> harvestCookies(
    BuildContext context,
    String url, {
    bool showWebView = false,
  }) async {
    try {
      final ok = await _doHarvest(context, url, showWebView);
      if (ok) return true;
    } catch (_) {}
    if (!showWebView && context.mounted) {
      try {
        return await _doHarvest(context, url, true);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<bool> _doHarvest(BuildContext context, String url, bool visible) async {
    final domain = Uri.parse(url).host;
    final completer = Completer<bool>();

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          try {
            final existingUA = await _storage.read(key: _uaKey);
            if (existingUA == null) {
              final ua = await controller
                  .runJavaScriptReturningResult('navigator.userAgent');
              final cleaned = ua.toString().replaceAll('"', '');
              if (cleaned.isNotEmpty) {
                await _storage.write(key: _uaKey, value: cleaned);
              }
            }
            final raw =
                await controller.runJavaScriptReturningResult('document.cookie');
            var cookieStr = raw.toString();
            if (cookieStr.startsWith('"') && cookieStr.endsWith('"')) {
              cookieStr = cookieStr.substring(1, cookieStr.length - 1);
            }
            if (cookieStr.isNotEmpty) {
              await _storage.write(key: 'cookies_$domain', value: cookieStr);
              if (!completer.isCompleted) completer.complete(true);
            } else if (!visible) {
              if (!completer.isCompleted) completer.complete(false);
            }
          } catch (_) {
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onWebResourceError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ));

    await controller.loadRequest(Uri.parse(url));

    if (visible) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _VisibleHarvestPage(
          controller: controller,
          domain: domain,
          onDone: () {
            if (!completer.isCompleted) completer.complete(true);
          },
        ),
      ));
      if (!completer.isCompleted) completer.complete(false);
      return completer.future;
    } else {
      final overlay = Overlay.of(context, rootOverlay: true);
      final entry = OverlayEntry(
        builder: (_) => SizedBox(
          width: 0,
          height: 0,
          child: WebViewWidget(controller: controller),
        ),
      );
      overlay.insert(entry);
      final result = await completer.future
          .timeout(const Duration(seconds: 25), onTimeout: () => false);
      entry.remove();
      return result;
    }
  }
}

class _VisibleHarvestPage extends StatelessWidget {
  final WebViewController controller;
  final String domain;
  final VoidCallback onDone;
  const _VisibleHarvestPage({
    required this.controller,
    required this.domain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) onDone();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Verify $domain'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Done',
              onPressed: () {
                onDone();
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
        body: WebViewWidget(controller: controller),
      ),
    );
  }
}
