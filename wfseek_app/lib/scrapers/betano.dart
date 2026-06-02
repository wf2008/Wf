import 'scraper_base.dart';
import 'config.dart';

// Betano Nigeria (Kaizen Gaming platform) – ng.betano.com
class BetanoScraper extends ScraperBase {
  BetanoScraper() : super(bookmakerById('betano')!);

  static const _sportSlugs = {'soccer':'soccer','basketball':'basketball','tennis':'tennis','volleyball':'volleyball','hockey':'ice-hockey','american_football':'american-football'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final slug = _sportSlugs[sport]; if (slug == null) return [];
    try {
      final r = await get(
        '/api/sports/$slug/events/',
        query: {'market': _mkt(market), 'lang': 'en', 'country': 'ng', 'limit': '200'},
      );
      final body = r.data;
      final events = body?['data']?['events'] ?? body?['events'] ?? body?['blocks'];
      if (events is! List) return _tryAlt(slug, sport, market);
      return _parse(events, sport, market);
    } catch (_) { return _tryAlt(slug!, sport, market); }
  }

  Future<List<Map<String, dynamic>>> _tryAlt(String slug, String sport, String market) async {
    try {
      final r = await get('/api/events', query: {'sport': slug, 'market': _mkt(market), 'limit': '200', 'status': 'upcoming'});
      final events = r.data?['events'] ?? r.data?['data']; if (events is! List) return [];
      return _parse(events, sport, market);
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _parse(List events, String sport, String market) {
    final out = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final id = (ev['id'] ?? ev['eventId'] ?? '').toString();
      final home = (ev['homeTeam']?['name'] ?? ev['homeTeam'] ?? ev['home'] ?? ev['competitors']?[0]?['name'] ?? '').toString().trim();
      final away = (ev['awayTeam']?['name'] ?? ev['awayTeam'] ?? ev['away'] ?? ev['competitors']?[1]?['name'] ?? '').toString().trim();
      if (home.isEmpty || away.isEmpty) continue;
      final league = (ev['league']?['name'] ?? ev['league'] ?? ev['competition']?['name'] ?? ev['tournament']?['name'] ?? '').toString();
      final mks = ev['markets'] ?? ev['odds'];
      if (mks == null) continue;
      _extractMarkets(id, home, away, league, sport, market, mks, out);
    }
    return out;
  }

  void _extractMarkets(String id, String home, String away, String league, String sport, String market, dynamic mks, List<Map<String,dynamic>> out) {
    final mkList = mks is List ? mks : (mks is Map ? [mks] : []);
    for (final mk in mkList) {
      if (mk is! Map) continue;
      final selections = mk['selections'] ?? mk['outcomes'] ?? mk['odds'];
      if (selections == null) continue;
      final selList = selections is List ? selections : [];
      final outcomes = <String, dynamic>{};
      final ouLines = <String, List<double>>{};
      for (final sel in selList) {
        if (sel is! Map) continue;
        final name = (sel['name'] ?? sel['label'] ?? sel['type'] ?? '').toString().toLowerCase().trim();
        final odds = _d(sel['price'] ?? sel['odds'] ?? sel['value'] ?? sel['coef']);
        if (odds == null) continue;
        switch (market) {
          case '1x2':
            if (name.contains('home')||name=='1'||name=='w1') outcomes['Home']=odds;
            else if (name.contains('draw')||name=='x') outcomes['Draw']=odds;
            else if (name.contains('away')||name=='2'||name=='w2') outcomes['Away']=odds;
            break;
          case 'moneyline': case 'winner':
            if (name.contains('home')||name=='1') outcomes['Home']=odds;
            else if (name.contains('away')||name=='2') outcomes['Away']=odds;
            break;
          case 'over_under':
            final line = RegExp(r'[\d.]+').allMatches(name).map((m)=>m.group(0)!).where((s)=>double.tryParse(s)!=null).toList();
            final l = line.isNotEmpty ? line.first : '2.5';
            ouLines.putIfAbsent(l, () => [0.0, 0.0]);
            if (name.contains('over')) ouLines[l]![0] = odds;
            else if (name.contains('under')) ouLines[l]![1] = odds;
            break;
          case 'double_chance':
            if (name.contains('1x')||name.contains('home or draw')) outcomes['1X']=odds;
            else if (name.contains('x2')||name.contains('draw or away')) outcomes['X2']=odds;
            else if (name.contains('12')||name.contains('home or away')) outcomes['12']=odds;
            break;
          case 'btts':
            if (name.contains('yes')||name.contains('gg')) outcomes['Yes']=odds;
            else if (name.contains('no')||name.contains('ng')) outcomes['No']=odds;
            break;
        }
      }
      if (market == 'over_under') {
        for (final entry in ouLines.entries) { if (entry.value[0]>1 && entry.value[1]>1) out.add({'id':'${id}_ou_${entry.key}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':'Over/Under ${entry.key}','outcomes':{'Over':entry.value[0],'Under':entry.value[1]}}); }
      } else if (outcomes.length >= 2) {
        out.add({'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':outcomes});
      }
    }
  }

  String _mkt(String market) { switch(market) { case '1x2': return 'match_result'; case 'over_under': return 'total_goals'; case 'double_chance': return 'double_chance'; case 'btts': return 'both_teams_to_score'; case 'moneyline': return 'match_winner'; case 'winner': return 'match_winner'; default: return market; } }
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
