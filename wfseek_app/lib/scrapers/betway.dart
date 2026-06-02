import 'scraper_base.dart';
import 'config.dart';

// Betway Nigeria – proprietary sports API
class BetwayScraper extends ScraperBase {
  BetwayScraper() : super(bookmakerById('betway')!);

  static const _sportSlugs = {'soccer':'football','basketball':'basketball','tennis':'tennis','volleyball':'volleyball','hockey':'ice-hockey','american_football':'american-football'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportSlug = _sportSlugs[sport]; if (sportSlug == null) return [];
    try {
      // Betway NG uses sports.betway.com API
      final r = await get(
        'https://sports.betway.com/api/bet/getEvents',
        query: {'lang': 'en', 'country': 'NG', 'sport': sportSlug, 'type': _marketParam(market), 'count': '200'},
      );
      final body = r.data;
      final events = body?['events'] ?? body?['data']?['events'];
      if (events is List) return _parse(events, sport, market);
      return _tryNgApi(sportSlug, sport, market);
    } catch (_) { return _tryNgApi(sportSlug!, sport, market); }
  }

  Future<List<Map<String, dynamic>>> _tryNgApi(String sportSlug, String sport, String market) async {
    try {
      final r = await get('/api/sports/v1/events', query: {'sport': sportSlug, 'market': _marketParam(market), 'count': '200'});
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
      final home = (ev['homeTeam'] ?? ev['home'] ?? ev['Team1'] ?? ev['homeName'] ?? '').toString().trim();
      final away = (ev['awayTeam'] ?? ev['away'] ?? ev['Team2'] ?? ev['awayName'] ?? '').toString().trim();
      if (home.isEmpty || away.isEmpty) continue;
      final league = (ev['league'] ?? ev['competition'] ?? ev['leagueName'] ?? '').toString();
      final odds = ev['odds'] ?? ev['markets'] ?? ev['price'];
      if (odds == null) continue;
      final normalized = _normalizeOdds(odds, market, id);
      for (final item in normalized) {
        out.add({'id':'${id}_${item['detail']}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':item['detail'],'outcomes':item['outcomes']});
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _normalizeOdds(dynamic odds, String market, String id) {
    final result = <Map<String, dynamic>>[];
    if (market == '1x2') {
      double? h, dr, a;
      if (odds is Map) { h = _d(odds['W1'] ?? odds['home'] ?? odds['1']); dr = _d(odds['X'] ?? odds['draw']); a = _d(odds['W2'] ?? odds['away'] ?? odds['2']); }
      else if (odds is List) { for (final o in odds) { if (o is! Map) continue; final n = (o['name']??o['label']??o['betType']??'').toString().toLowerCase(); final v = _d(o['odds']??o['price']??o['coef']??o['value']); if (n.contains('home')||n=='1'||n=='w1') h=v; else if (n.contains('draw')||n=='x') dr=v; else if (n.contains('away')||n=='2'||n=='w2') a=v; } }
      if (h != null && dr != null && a != null) result.add({'detail': '1x2', 'outcomes': {'Home':h,'Draw':dr,'Away':a}});
    } else if (market == 'moneyline' || market == 'winner') {
      double? h, a;
      if (odds is Map) { h = _d(odds['W1']??odds['home']??odds['1']); a = _d(odds['W2']??odds['away']??odds['2']); }
      else if (odds is List) { for (final o in odds) { if (o is! Map) continue; final n = (o['name']??o['label']??'').toString().toLowerCase(); final v = _d(o['odds']??o['price']??o['value']); if (n.contains('home')||n=='1') h=v; else if (n.contains('away')||n=='2') a=v; } }
      if (h != null && a != null) result.add({'detail': market, 'outcomes': {'Home':h,'Away':a}});
    } else if (market == 'over_under') {
      if (odds is List) {
        final overs = <String, double>{}, unders = <String, double>{};
        for (final o in odds) { if (o is! Map) continue; final n = (o['name']??o['label']??'').toString().toLowerCase(); final v = _d(o['odds']??o['price']??o['value']); if (v==null) continue; final m = RegExp(r'[\d.]+').allMatches(n).map((x)=>x.group(0)!).where((s)=>double.tryParse(s)!=null).toList(); final line = m.isNotEmpty ? m.first : '2.5'; if (n.contains('over')) overs[line]=v; else if (n.contains('under')) unders[line]=v; }
        for (final line in overs.keys) { if (unders.containsKey(line)) result.add({'detail':'Over/Under $line','outcomes':{'Over':overs[line]!,'Under':unders[line]!}}); }
      } else if (odds is Map) { final o = _d(odds['Over']??odds['over']); final u = _d(odds['Under']??odds['under']); if (o!=null&&u!=null) result.add({'detail':'Over/Under 2.5','outcomes':{'Over':o,'Under':u}}); }
    } else if (market == 'btts') {
      double? y, n;
      if (odds is Map) { y=_d(odds['Yes']??odds['yes']??odds['GG']); n=_d(odds['No']??odds['no']??odds['NG']); }
      else if (odds is List) { for (final o in odds) { if (o is! Map) continue; final nm=(o['name']??o['label']??'').toString().toLowerCase(); final v=_d(o['odds']??o['price']??o['value']); if (nm.contains('yes')||nm.contains('gg')) y=v; else if (nm.contains('no')||nm.contains('ng')) n=v; } }
      if (y!=null&&n!=null) result.add({'detail':'btts','outcomes':{'Yes':y,'No':n}});
    } else if (market == 'double_chance') {
      double? ox, xt, ot;
      if (odds is Map) { ox=_d(odds['1X']??odds['1x']); xt=_d(odds['X2']??odds['x2']); ot=_d(odds['12']); }
      else if (odds is List) { for (final o in odds) { if (o is! Map) continue; final n=(o['name']??o['label']??'').toString().toLowerCase(); final v=_d(o['odds']??o['price']??o['value']); if (n.contains('1x')||n.contains('home or draw')) ox=v; else if (n.contains('x2')||n.contains('draw or away')) xt=v; else if (n.contains('12')||n.contains('home or away')) ot=v; } }
      if (ox!=null&&xt!=null&&ot!=null) result.add({'detail':'double_chance','outcomes':{'1X':ox,'X2':xt,'12':ot}});
    }
    return result;
  }

  String _marketParam(String market) { switch (market) { case '1x2': return 'match_result'; case 'over_under': return 'total_goals'; case 'double_chance': return 'double_chance'; case 'btts': return 'both_teams_to_score'; case 'moneyline': return 'match_winner'; case 'winner': return 'match_winner'; default: return market; } }
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
