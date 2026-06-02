import 'scraper_base.dart';
import 'config.dart';

// Cloudbet – public sportsbook API at sports-api.cloudbet.com
class CloudbetScraper extends ScraperBase {
  CloudbetScraper() : super(bookmakerById('cloudbet')!);

  static const _sportKeys = {'soccer':'soccer','basketball':'basketball','tennis':'tennis','volleyball':'volleyball','hockey':'ice-hockey','american_football':'american-football'};
  static const _marketGroups = {
    'soccer': {'1x2':'soccer.match_odds','over_under':'soccer.totals','double_chance':'soccer.double_chance','btts':'soccer.both_teams_to_score'},
    'basketball': {'moneyline':'basketball.moneyline','over_under':'basketball.totals'},
    'tennis': {'winner':'tennis.match_odds'},
    'volleyball': {'winner':'volleyball.match_odds'},
    'hockey': {'moneyline':'ice-hockey.moneyline'},
    'american_football': {'moneyline':'american-football.moneyline'},
  };

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportKey = _sportKeys[sport]; if (sportKey == null) return [];
    final marketKey = _marketGroups[sport]?[market]; if (marketKey == null) return [];
    try {
      final r = await get(
        'https://sports-api.cloudbet.com/pub/v2/odds/sports/$sportKey',
        query: {'lang': 'en', 'marketGroup': marketKey, 'pageSize': '200'},
      );
      final competitions = r.data?['sports']?.first?['competitions'];
      if (competitions is! List) return _tryAltPath(r.data, sport, market, marketKey);
      final out = <Map<String, dynamic>>[];
      for (final comp in competitions) {
        if (comp is! Map) continue;
        final league = (comp['name'] ?? '').toString();
        final events = comp['events'];
        if (events is! List) continue;
        for (final ev in events) {
          if (ev is! Map) continue;
          final id = (ev['id'] ?? ev['key'] ?? '').toString();
          final name = (ev['name'] ?? '').toString();
          String home = '', away = '';
          if (ev['home'] is Map) {
            home = ((ev['home'] as Map)['name'] ?? '').toString();
            away = ((ev['away'] as Map)['name'] ?? '').toString();
          } else {
            final parts = name.split(' v ');
            if (parts.length == 2) { home = parts[0].trim(); away = parts[1].trim(); }
          }
          if (home.isEmpty || away.isEmpty) continue;
          final markets = ev['markets'] as Map?; if (markets == null) continue;
          final mk = markets[marketKey]; if (mk is! Map) continue;
          final sels = mk['selections'] as Map?; if (sels == null) continue;
          final outcomes = _parseSelections(sels, market);
          if (outcomes.length < 2) continue;
          out.add({'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':outcomes});
        }
      }
      return out;
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _tryAltPath(dynamic data, String sport, String market, String marketKey) {
    try {
      final events = data?['events'] ?? data?['data'];
      if (events is! List) return [];
      final out = <Map<String, dynamic>>[];
      for (final ev in events) {
        if (ev is! Map) continue;
        final home = (ev['home']?['name'] ?? ev['homeTeam'] ?? '').toString().trim();
        final away = (ev['away']?['name'] ?? ev['awayTeam'] ?? '').toString().trim();
        if (home.isEmpty || away.isEmpty) continue;
        final sels = (ev['markets'] as Map?)?[marketKey]?['selections'];
        if (sels is! Map) continue;
        final outcomes = _parseSelections(sels, market);
        if (outcomes.length < 2) continue;
        out.add({'id':'${ev['id']}_$market','home_team':home,'away_team':away,'league':'','category':'','sport':sport,'market':market,'market_detail':market,'outcomes':outcomes});
      }
      return out;
    } catch (_) { return []; }
  }

  Map<String, dynamic> _parseSelections(Map sels, String market) {
    final outcomes = <String, dynamic>{};
    if (market == '1x2') {
      final h = _d(sels['home']?['price']); final dr = _d(sels['draw']?['price']); final a = _d(sels['away']?['price']);
      if (h != null && dr != null && a != null) { outcomes['Home'] = h; outcomes['Draw'] = dr; outcomes['Away'] = a; }
    } else if (market == 'moneyline' || market == 'winner') {
      final h = _d(sels['home']?['price']); final a = _d(sels['away']?['price']);
      if (h != null && a != null) { outcomes['Home'] = h; outcomes['Away'] = a; }
    } else if (market == 'over_under') {
      sels.forEach((k, v) {
        final label = k.toString().toLowerCase();
        if (label.startsWith('over') || label.startsWith('under')) {
          final d = _d((v as Map)['price']); if (d != null) outcomes[label.contains('over') ? 'Over' : 'Under'] = d;
        }
      });
    } else if (market == 'double_chance') {
      final ox = _d(sels['1x']?['price'] ?? sels['home_draw']?['price']); final xt = _d(sels['x2']?['price'] ?? sels['away_draw']?['price']); final ot = _d(sels['12']?['price'] ?? sels['home_away']?['price']);
      if (ox != null) outcomes['1X'] = ox; if (xt != null) outcomes['X2'] = xt; if (ot != null) outcomes['12'] = ot;
    } else if (market == 'btts') {
      final y = _d(sels['yes']?['price']); final n = _d(sels['no']?['price']);
      if (y != null) outcomes['Yes'] = y; if (n != null) outcomes['No'] = n;
    }
    return outcomes;
  }

  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
