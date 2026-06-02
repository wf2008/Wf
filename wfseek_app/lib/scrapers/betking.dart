import 'scraper_base.dart';
import 'config.dart';

// BetKing Nigeria – proprietary sports API at gaming.betking.com
class BetKingScraper extends ScraperBase {
  BetKingScraper() : super(bookmakerById('betking')!);

  static const _sportIds = {'soccer':'1','basketball':'2','tennis':'5','volleyball':'34','hockey':'4','american_football':'9'};
  static const _marketIds = {'1x2':'1','over_under':'18','double_chance':'10','btts':'29','moneyline':'1','winner':'1'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportId = _sportIds[sport]; if (sportId == null) return [];
    final marketId = _marketIds[market]; if (marketId == null) return [];
    try {
      final r = await get(
        '/api/v1/events',
        query: {'sportId': sportId, 'marketId': marketId, 'status': 'UPCOMING', 'limit': '200', 'lang': 'en'},
      );
      final body = r.data;
      final events = body?['data']?['events'] ?? body?['events'] ?? body?['result'];
      if (events is! List) return _tryAlt(sportId, marketId, sport, market);
      return _parse(events, sport, market);
    } catch (_) { return _tryAlt(_sportIds[sport]!, _marketIds[market]!, sport, market); }
  }

  Future<List<Map<String, dynamic>>> _tryAlt(String sportId, String marketId, String sport, String market) async {
    try {
      final r = await get(
        'https://gaming.betking.com/sports/v1/groups.json',
        query: {'sport': sportId, 'market': marketId, 'count': '200'},
      );
      final events = r.data?['events'] ?? r.data?['data'];
      if (events is! List) return [];
      return _parse(events, sport, market);
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _parse(List events, String sport, String market) {
    final out = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final id = (ev['id'] ?? ev['eventId'] ?? '').toString();
      final home = (ev['homeTeam'] ?? ev['home'] ?? ev['homeName'] ?? ev['team1'] ?? '').toString().trim();
      final away = (ev['awayTeam'] ?? ev['away'] ?? ev['awayName'] ?? ev['team2'] ?? '').toString().trim();
      if (home.isEmpty || away.isEmpty) continue;
      final league = (ev['league'] ?? ev['leagueName'] ?? ev['competition'] ?? ev['tournamentName'] ?? '').toString();
      final markets = ev['markets'] ?? ev['odds']; if (markets == null) continue;
      final result = _extractMarket(id, home, away, league, sport, market, markets);
      if (result != null) out.add(result);
    }
    return out;
  }

  Map<String, dynamic>? _extractMarket(String id, String home, String away, String league, String sport, String market, dynamic mk) {
    if (mk is List) {
      for (final m in mk) {
        if (m is! Map) continue;
        final result = _parseMarketObj(id, home, away, league, sport, market, m);
        if (result != null) return result;
      }
    } else if (mk is Map) {
      return _parseMarketObj(id, home, away, league, sport, market, mk);
    }
    return null;
  }

  Map<String, dynamic>? _parseMarketObj(String id, String home, String away, String league, String sport, String market, Map mk) {
    final outcomes = mk['outcomes'] ?? mk['selections'] ?? mk['odds'];
    if (outcomes == null) return null;
    Map<String, dynamic> normalized = {};
    if (market == '1x2') {
      normalized = _extract1x2(outcomes);
    } else if (market == 'over_under') {
      final lines = _extractOU(outcomes);
      if (lines.isEmpty) return null;
      final entry = lines.entries.first;
      return {'id':'${id}_ou_${entry.key}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':'Over/Under ${entry.key}','outcomes':{'Over':entry.value[0],'Under':entry.value[1]}};
    } else if (market == 'double_chance') {
      normalized = _extractDC(outcomes);
    } else if (market == 'btts') {
      normalized = _extractBTTS(outcomes);
    } else if (market == 'moneyline' || market == 'winner') {
      normalized = _extractML(outcomes);
    }
    if (normalized.length < 2) return null;
    return {'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':normalized};
  }

  Map<String, dynamic> _extract1x2(dynamic odds) {
    if (odds is Map) {
      final h = _d(odds['Home'] ?? odds['home'] ?? odds['1'] ?? odds['W1']); final dr = _d(odds['Draw'] ?? odds['draw'] ?? odds['X']); final a = _d(odds['Away'] ?? odds['away'] ?? odds['2'] ?? odds['W2']);
      if (h != null && dr != null && a != null) return {'Home':h,'Draw':dr,'Away':a};
    } else if (odds is List) {
      double? h, dr, a;
      for (final o in odds) {
        if (o is! Map) continue;
        final n = (o['name'] ?? o['label'] ?? o['type'] ?? '').toString().toLowerCase();
        final v = _d(o['odds'] ?? o['price'] ?? o['value'] ?? o['coef']);
        if (n.contains('home') || n == '1' || n == 'w1') h = v;
        else if (n.contains('draw') || n == 'x') dr = v;
        else if (n.contains('away') || n == '2' || n == 'w2') a = v;
      }
      if (h != null && dr != null && a != null) return {'Home':h,'Draw':dr,'Away':a};
    }
    return {};
  }

  Map<String, dynamic> _extractML(dynamic odds) {
    if (odds is Map) {
      final h = _d(odds['Home'] ?? odds['home'] ?? odds['1'] ?? odds['W1']); final a = _d(odds['Away'] ?? odds['away'] ?? odds['2'] ?? odds['W2']);
      if (h != null && a != null) return {'Home':h,'Away':a};
    } else if (odds is List) {
      double? h, a;
      for (final o in odds) {
        if (o is! Map) continue;
        final n = (o['name'] ?? o['label'] ?? '').toString().toLowerCase(); final v = _d(o['odds'] ?? o['price'] ?? o['value']);
        if (n.contains('home') || n == '1') h = v; else if (n.contains('away') || n == '2') a = v;
      }
      if (h != null && a != null) return {'Home':h,'Away':a};
    }
    return {};
  }

  Map<String, dynamic> _extractDC(dynamic odds) {
    final result = <String, dynamic>{};
    if (odds is List) {
      for (final o in odds) {
        if (o is! Map) continue;
        final n = (o['name'] ?? o['label'] ?? '').toString().toLowerCase(); final v = _d(o['odds'] ?? o['price'] ?? o['value']);
        if (v == null) continue;
        if (n.contains('1x') || n.contains('home or draw')) result['1X'] = v;
        else if (n.contains('x2') || n.contains('draw or away')) result['X2'] = v;
        else if (n.contains('12') || n.contains('home or away')) result['12'] = v;
      }
    } else if (odds is Map) {
      final ox = _d(odds['1X'] ?? odds['1x'] ?? odds['HomeOrDraw']); final xt = _d(odds['X2'] ?? odds['x2'] ?? odds['DrawOrAway']); final ot = _d(odds['12'] ?? odds['HomeOrAway']);
      if (ox != null) result['1X'] = ox; if (xt != null) result['X2'] = xt; if (ot != null) result['12'] = ot;
    }
    return result;
  }

  Map<String, dynamic> _extractBTTS(dynamic odds) {
    final result = <String, dynamic>{};
    if (odds is List) {
      for (final o in odds) {
        if (o is! Map) continue;
        final n = (o['name'] ?? o['label'] ?? '').toString().toLowerCase(); final v = _d(o['odds'] ?? o['price'] ?? o['value']);
        if (v == null) continue;
        if (n.contains('yes') || n.contains('gg')) result['Yes'] = v;
        else if (n.contains('no') || n.contains('ng')) result['No'] = v;
      }
    } else if (odds is Map) {
      final y = _d(odds['Yes'] ?? odds['yes'] ?? odds['GG']); final n = _d(odds['No'] ?? odds['no'] ?? odds['NG']);
      if (y != null) result['Yes'] = y; if (n != null) result['No'] = n;
    }
    return result;
  }

  Map<String, List<double>> _extractOU(dynamic odds) {
    final result = <String, List<double>>{};
    if (odds is List) {
      final overItems = <String, double>{}, underItems = <String, double>{};
      for (final o in odds) {
        if (o is! Map) continue;
        final n = (o['name'] ?? o['label'] ?? '').toString().toLowerCase(); final v = _d(o['odds'] ?? o['price'] ?? o['value']);
        if (v == null) continue;
        final lineMatch = RegExp(r'[\d.]+').allMatches(n).map((m) => m.group(0)!).where((s) => double.tryParse(s) != null).toList();
        final line = lineMatch.isNotEmpty ? lineMatch.first : '2.5';
        if (n.contains('over')) overItems[line] = v; else if (n.contains('under')) underItems[line] = v;
      }
      for (final line in overItems.keys) {
        if (underItems.containsKey(line)) result[line] = [overItems[line]!, underItems[line]!];
      }
    }
    return result;
  }

  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
