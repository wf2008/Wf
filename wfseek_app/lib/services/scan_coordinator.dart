import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../scrapers/config.dart';
import '../scrapers/registry.dart';
import '../scrapers/scraper_base.dart';
import 'team_matcher.dart';
import 'arb_detector.dart';

class ScanCoordinator {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final TeamMatcher _matcher = TeamMatcher();
  final ArbDetector _detector = ArbDetector();
  final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();

  /// Try to claim the global scan lock. Returns true if scan was performed.
  Future<bool> attemptAutomaticScan({String? uid}) async {
    if (!await _online()) return false;
    final stateRef = _db.ref('scan_state');
    final now = DateTime.now().millisecondsSinceEpoch;
    final txn = await stateRef.runTransaction((current) {
      Map<String, dynamic> m = current is Map
          ? Map<String, dynamic>.from(current as Map)
          : {};
      final inProgress = m['scan_in_progress'] == true;
      final last = m['last_scan_utc'];
      final stale = last is int && (now - last) > 5 * 60 * 1000;
      if (inProgress && !stale) {
        return Transaction.abort();
      }
      m['scan_in_progress'] = true;
      m['scanner_uid'] = uid ?? 'anonymous';
      m['last_scan_utc'] = now;
      return Transaction.success(m);
    });
    if (!txn.committed) return false;
    try {
      final result = await _performScan();
      await _publish(result.opportunities);
      await _releaseScan(skipped: result.skipped);
      return true;
    } catch (_) {
      // Release the lock even on failure so others can scan.
      await _releaseScan(skipped: const []);
      return false;
    }
  }

  /// User-triggered scan – no lock. Last writer wins.
  Future<List<Map<String, dynamic>>> manualScan() async {
    if (!await _online()) return [];
    final result = await _performScan();
    await _publish(result.opportunities);
    // Touch scan_state so other clients can see freshness.
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.ref('scan_state').update({
      'last_scan_utc': now,
      'next_scan_utc': now + (8 + Random().nextInt(5)) * 60 * 1000,
      'scan_in_progress': false,
    });
    if (result.skipped.isNotEmpty) {
      await _notifySkipped(result.skipped);
    }
    return result.opportunities;
  }

  Future<bool> _online() async {
    final c = await Connectivity().checkConnectivity();
    return c != ConnectivityResult.none;
  }

  Future<void> _publish(List<Map<String, dynamic>> opps) async {
    await _db.ref('opportunities').set(opps);
  }

  Future<void> _releaseScan({required List<String> skipped}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = now + (8 + Random().nextInt(5)) * 60 * 1000;
    await _db.ref('scan_state').update({
      'scan_in_progress': false,
      'last_scan_utc': now,
      'next_scan_utc': next,
    });
    if (skipped.isNotEmpty) {
      await _notifySkipped(skipped);
    }
  }

  Future<void> _notifySkipped(List<String> skipped) async {
    try {
      const android = AndroidNotificationDetails(
        'wfseek_scan', 'Scan alerts',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const details = NotificationDetails(android: android);
      await _flnp.show(
        42,
        'Bookmakers need verification',
        skipped.join(', '),
        details,
      );
    } catch (_) {}
  }

  Future<_ScanResult> _performScan() async {
    final scrapers = buildAllScrapers();
    final skipped = <String>[];
    final allOpps = <Map<String, dynamic>>[];

    for (final sport in sports) {
      final markets = marketsBySport[sport] ?? const <String>[];
      for (final market in markets) {
        final oddsByBm = <String, List<Map<String, dynamic>>>{};
        final providesByBm = <String, bool>{};

        for (final entry in scrapers.entries) {
          final bmId = entry.key;
          final scraper = entry.value;
          providesByBm[bmId] = scraper.config.providesLeagueCategory;
          try {
            final hasCookies = await scraper.ensureCookies(context: null);
            if (!hasCookies) {
              if (!skipped.contains(scraper.config.name)) {
                skipped.add(scraper.config.name);
              }
              continue;
            }
            final list = await scraper.getOdds(sport, market);
            if (list.isNotEmpty) {
              oddsByBm[bmId] = list;
            }
          } on CloudflareChallengeException {
            if (!skipped.contains(scraper.config.name)) {
              skipped.add(scraper.config.name);
            }
          } catch (_) {
            // network or parse error – just skip this bookmaker for this market
          }
        }

        if (oddsByBm.length < 2) continue;
        final groups = await _matcher.matchTeams(
          oddsByBm, sport, market,
          providesLeagueCategoryByBm: providesByBm,
        );
        final arbs = _detector.detectArbs(groups);
        for (final a in arbs) {
          allOpps.add(a.toMap());
        }
      }
    }
    return _ScanResult(allOpps, skipped);
  }
}

class _ScanResult {
  final List<Map<String, dynamic>> opportunities;
  final List<String> skipped;
  _ScanResult(this.opportunities, this.skipped);
}
