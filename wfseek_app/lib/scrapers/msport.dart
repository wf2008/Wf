import 'scraper_base.dart';
import 'config.dart';

// MSport Nigeria – msport.com API
class MSportScraper extends ScraperBase {
  MSportScraper() : super(bookmakerById('msport')!);

  static const _sportIds = {'soccer':'1','basketball':'2','tennis':'13','volleyball':'91','hockey':'4','american_football':'15'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportId = _sportIds[sport]; if (sportId == null) return [];
    try {
      final r = await get(
        '/api/sport/$sportId/events',
        query: {'market': _mkt(market), 'count': '200', 'lang': 'en', 'status': 'upcoming'},
      );
      final body = r.data;
      final events = body?['data'] ?? body?['events'] ?? body?['result'];
      if (events is List) return _parse(events, sport, market);
      return _tryCompetitionApi(sportId, sport, market);
    } catch (_) { return _tryCompetitionApi(_sportIds[sport]!, sport, market); }
  }

  Future<List<Map<String, dynamic>>> _tryCompetitionApi(String sportId, String sport, String market) async {
    try {
      final r = await get('/api/competition/allMatch', query: {'sport': sportId, 'marketId': _mktId(market), 'count': '200'});
      final events = r.data?['data'] ?? r.data?['matches']; if (events is! List) return [];
      return _parse(events, sport, market);
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _parse(List events, String sport, String market) {
    final out = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final id = (ev['id'] ?? ev['matchId'] ?? ev['eventId'] ?? '').toString();
      final home = (ev['homeTeam'] ?? ev['home'] ?? ev['homeName'] ?? ev['teamHome'] ?? '').toString().trim();
      final away = (ev['awayTeam'] ?? ev['away'] ?? ev['awayName'] ?? ev['teamAway'] ?? '').toString().trim();
      if (home.isEmpty || away.isEmpty) continue;
      final league = (ev['league'] ?? ev['leagueName'] ?? ev['competition'] ?? ev['tournament'] ?? '').toString();
      final mks = ev['markets'] ?? ev['odds'] ?? ev['bet'];
      if (mks == null) continue;
      _parseMarkets(id, home, away, league, sport, market, mks, out);
    }
    return out;
  }

  void _parseMarkets(String id, String home, String away, String league, String sport, String market, dynamic mks, List<Map<String,dynamic>> out) {
    final list = mks is List ? mks : (mks is Map ? mks.values.toList() : []);
    for (final mk in list) {
      if (mk is! Map) continue;
      final selections = mk['selections'] ?? mk['outcomes'] ?? mk['odds'];
      if (selections == null) continue;
      final selList = selections is List ? selections : [];
      final outcomes = <String, dynamic>{};
      final ouLines = <String, List<double>>{};
      for (final sel in selList) {
        if (sel is! Map) continue;
        final name = (sel['name'] ?? sel['label'] ?? sel['type'] ?? '').toString().toLowerCase().trim();
        final odds = _d(sel['price'] ?? sel['odds'] ?? sel['value'] ?? sel['odd']);
        if (odds == null) continue;
        if (market == '1x2') {
          if (name.contains('home')||name=='1'||name=='w1') outcomes['Home']=odds;
          else if (name.contains('draw')||name=='x') outcomes['Draw']=odds;
          else if (name.contains('away')||name=='2'||name=='w2') outcomes['Away']=odds;
        } else if (market == 'moneyline' || market == 'winner') {
          if (name.contains('home')||name=='1') outcomes['Home']=odds;
          else if (name.contains('away')||name=='2') outcomes['Away']=odds;
        } else if (market == 'over_under') {
          final m = RegExp(r'[\d.]+').allMatches(name).map((x)=>x.group(0)!).where((s)=>double.tryParse(s)!=null).toList();
          final l = m.isNotEmpty ? m.first : '2.5';
          ouLines.putIfAbsent(l, ()=>[0.0,0.0]);
          if (name.contains('over')) ouLines[l]![0]=odds; else if (name.contains('under')) ouLines[l]![1]=odds;
        } else if (market == 'double_chance') {
          if (name.contains('1x')||name.contains('home or draw')) outcomes['1X']=odds;
          else if (name.contains('x2')||name.contains('draw or away')) outcomes['X2']=odds;
          else if (name.contains('12')||name.contains('home or away')) outcomes['12']=odds;
        } else if (market == 'btts') {
          if (name.contains('yes')||name.contains('gg')) outcomes['Yes']=odds;
          else if (name.contains('no')||name.contains('ng')) outcomes['No']=odds;
        }
      }
      if (market == 'over_under') {
        for (final e in ouLines.entries) { if (e.value[0]>1&&e.value[1]>1) out.add({'id':'${id}_ou_${e.key}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':'Over/Under ${e.key}','outcomes':{'Over':e.value[0],'Under':e.value[1]}}); }
      } else if (outcomes.length >= 2) {
        out.add({'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':outcomes});
      }
    }
  }

  String _mkt(String m) { switch(m) { case '1x2': return '1X2'; case 'over_under': return 'OU'; case 'double_chance': return 'DC'; case 'btts': return 'GG'; case 'moneyline': return 'ML'; case 'winner': return 'WINNER'; default: return m; } }
  String _mktId(String m) { switch(m) { case '1x2': return '1'; case 'over_under': return '18'; case 'double_chance': return '10'; case 'btts': return '29'; default: return '1'; } }
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
