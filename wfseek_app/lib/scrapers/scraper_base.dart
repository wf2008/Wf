import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../services/cookie_manager.dart';
import 'config.dart';

class CloudflareChallengeException implements Exception {
  final String domain;
  CloudflareChallengeException(this.domain);
  @override
  String toString() => 'CloudflareChallengeException($domain)';
}

class MissingCookiesException implements Exception {
  final String domain;
  MissingCookiesException(this.domain);
  @override
  String toString() => 'MissingCookiesException($domain)';
}

/// Base class for every bookmaker scraper.
abstract class ScraperBase {
  final BookmakerConfig config;
  final CookieManager _cm = CookieManager();
  Dio? _dio;

  ScraperBase(this.config);

  String get domain => config.domain;
  String get baseUrl => config.baseUrl;
  bool get protected => config.protected;

  /// Ensure cookies exist for this bookmaker. If [context] is provided and
  /// cookies are missing, this method may open a (visible) WebView.
  Future<bool> ensureCookies({BuildContext? context}) async {
    if (await _cm.hasCookiesForDomain(domain)) return true;
    if (context == null) return false;
    return _cm.harvestCookies(context, baseUrl, showWebView: protected);
  }

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: true,
      validateStatus: (s) => s != null && s < 500,
    ));
    final ua = await _cm.getUserAgent();
    final cookieHeader = await _cm.getCookieHeader(domain);
    dio.options.headers.addAll({
      'User-Agent': ua ??
          'Mozilla/5.0 (Linux; Android 12; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': baseUrl,
      ...cookieHeader,
    });
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (resp, h) {
        if (resp.statusCode == 403) {
          final body = resp.data?.toString() ?? '';
          if (body.contains('Cloudflare') ||
              body.contains('cf-chl') ||
              body.contains('Just a moment')) {
            return h.reject(DioException(
              requestOptions: resp.requestOptions,
              error: CloudflareChallengeException(domain),
              response: resp,
            ));
          }
        }
        h.next(resp);
      },
    ));
    _dio = dio;
    return dio;
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    final c = await _client();
    final url = path.startsWith('http') ? path : '$baseUrl$path';
    final r = await c.get<T>(url, queryParameters: query);
    return r;
  }

  String? endpointFor(String sport, String market) =>
      config.endpoints[sport]?[market];

  /// Returns normalized event objects:
  /// {
  ///   id, home_team, away_team, league, category,
  ///   sport, market, market_detail, outcomes: { label: odds }
  /// }
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market);
}
