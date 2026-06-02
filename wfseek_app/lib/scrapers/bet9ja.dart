import 'scraper_base.dart';
import 'config.dart';

// Bet9ja real API (reverse-engineered from mobile app)
// Uses the legacy cache/feed endpoint at c1.bet9ja.com
// Also supports the newer sports-cache endpoint
class Bet9jaScraper extends ScraperBase {
  Bet9jaScraper() : super(bookmakerById('bet9ja')!);

  static const _sportCodes = {
    'soccer': 'FOOTBALL',
    'basketball': 'BASKETBALL',
    'tennis': 'TENNIS',
    'volleyball': 'VOLLEYBALL',
    'hockey': 'ICEHOCKEY',
    'american_football': 'AMERICANFOOTBALL',
  };

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportCode = _sportCodes[sport];
    if (sportCode == null) return [];

    try {
      // Bet9ja mobile API endpoint
      final resp = await get(
        'https://mobile.bet9ja.com/sports-api/sports/events',
        query: {
          'sport': sportCode,
          'market': _marketParam(market),
          'count': '200',
          'lang': 'en',
        },
      );

      final body = resp.data;
      if (body == null) return [];

      final events = body['events'] ?? body['data']?['events'] ?? body['result'];
      if (events is! List) return _parseLegacyFeed(sport, market);

      return _parseEvents(events, sport, market);
    } catch (_) {
      return _parseLegacyFeed(sport, market);
    }
  }

  Future<List<Map<String, dynamic>>> _parseLegacyFeed(String sport, String market) async {
    try {
      final resp = await get(
        'https://c1.bet9ja.com/cache/feed/',
        query: {
          'scopeLevel': '1',
          'action': 'getGames',
          'sport': _sportCodes[sport] ?? 'FOOTBALL',
          'type': _marketParam(market),
        },
      );

      final body = resp.data;
      if (body == null) return [];
      final gamesList = body['games'] ?? body['data'];
      if (gamesList is! List) return [];
      return _parseEvents(gamesList, sport, market);
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _parseEvents(List events, String sport, String market) {
    final results = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final id = (ev['id'] ?? ev['eventId'] ?? ev['GameId'] ?? '').toString();
      final home = (ev['home'] ?? ev['homeTeam'] ?? ev['Team1'] ?? ev['HomeName'] ?? '').toString().trim();
      final away = (ev['away'] ?? ev['awayTeam'] ?? ev['Team2'] ?? ev['AwayName'] ?? '').toString().trim();
      if (home.isEmpty || away.isEmpty) continue;

      final league = (ev['league'] ?? ev['leagueName'] ?? ev['competition'] ?? ev['ChampName'] ?? '').toString();
      final odds = ev['odds'] ?? ev['markets'] ?? ev['Odds'];

      if (market == '1x2' || market == 'moneyline' || market == 'winner') {
        double? h = _extractOdds(odds, ['home', 'W1', '1', 'Home', 'Coff1', 'homeOdds']);
        double? d = _extractOdds(odds, ['draw', 'X', 'Draw', 'CoffX', 'drawOdds']);
        double? a = _extractOdds(odds, ['away', 'W2', '2', 'Away', 'Coff2', 'awayOdds']);
        if (market == '1x2' && h != null && d != null && a != null) {
          results.add(_buildEvent(id, home, away, league, sport, market, market,
              {'Home': h, 'Draw': d, 'Away': a}));
        } else if ((market == 'moneyline' || market == 'winner') && h != null && a != null) {
          results.add(_buildEvent(id, home, away, league, sport, market, market,
              {'Home': h, 'Away': a}));
        }
      } else if (market == 'double_chance') {
        double? ox = _extractOdds(odds, ['1X', 'HomeOrDraw', 'dc1x', 'DC1X']);
        double? xt = _extractOdds(odds, ['X2', 'DrawOrAway', 'dcx2', 'DCX2']);
        double? ot = _extractOdds(odds, ['12', 'HomeOrAway', 'dc12', 'DC12']);
        if (ox != null && xt != null && ot != null) {
          results.add(_buildEvent(id, home, away, league, sport, market, market,
              {'1X': ox, 'X2': xt, '12': ot}));
        }
      } else if (market == 'btts') {
        double? y = _extractOdds(odds, ['Yes', 'yes', 'GG', 'gg', 'bttsYes']);
        double? n = _extractOdds(odds, ['No', 'no', 'NG', 'ng', 'bttsNo']);
        if (y != null && n != null) {
          results.add(_buildEvent(id, home, away, league, sport, market, market,
              {'Yes': y, 'No': n}));
        }
      } else if (market == 'over_under') {
        final lines = _extractOULines(odds);
        for (final entry in lines.entries) {
          results.add(_buildEvent(id, home, away, league, sport, market,
              'Over/Under ${entry.key}', {'Over': entry.value[0], 'Under': entry.value[1]}));
        }
      }
    }
    return results;
  }

  double? _extractOdds(dynamic odds, List<String> keys) {
    if (odds == null) return null;
    if (odds is Map) {
      for (final k in keys) {
        final v = odds[k];
        if (v != null) {
          final d = v is num ? v.toDouble() : double.tryParse('$v');
          if (d != null && d > 1.0) return d;
        }
      }
    }
    return null;
  }

  Map<String, List<double>> _extractOULines(dynamic odds) {
    final result = <String, List<double>>{};
    if (odds is! Map) return result;
    odds.forEach((key, val) {
      final k = key.toString().toLowerCase();
      if (k.contains('over') || k.contains('ou')) {
        final parts = k.split(RegExp(r'[_ ]'));
        String? line;
        for (final p in parts) {
          if (double.tryParse(p) != null) { line = p; break; }
        }
        line ??= '2.5';
        final overOdds = _extractOdds(val is Map ? val : odds,
            ['over', 'Over', 'More', 'more', '1']);
        final underOdds = _extractOdds(val is Map ? val : odds,
            ['under', 'Under', 'Less', 'less', '2']);
        if (overOdds != null && underOdds != null) {
          result[line] = [overOdds, underOdds];
        }
      }
    });
    // Fallback: check for standard OU keys
    if (result.isEmpty) {
      for (final line in ['1.5', '2.5', '3.5', '4.5']) {
        final o = _extractOdds(odds, ['over$line', 'Over$line', 'ou${line.replaceAll('.', '')}Over']);
        final u = _extractOdds(odds, ['under$line', 'Under$line', 'ou${line.replaceAll('.', '')}Under']);
        if (o != null && u != null) result[line] = [o, u];
      }
    }
    return result;
  }

  Map<String, dynamic> _buildEvent(String id, String home, String away, String league,
      String sport, String market, String detail, Map<String, dynamic> outcomes) {
    return {
      'id': '${id}_${market}',
      'home_team': home,
      'away_team': away,
      'league': league,
      'category': '',
      'sport': sport,
      'market': market,
      'market_detail': detail,
      'outcomes': outcomes,
    };
  }

  String _marketParam(String market) {
    switch (market) {
      case '1x2': return '1x2';
      case 'over_under': return 'ou';
      case 'double_chance': return 'dc';
      case 'btts': return 'gg';
      case 'moneyline': return 'ml';
      case 'winner': return 'winner';
      default: return market;
    }
  }
}
