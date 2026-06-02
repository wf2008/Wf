import 'scraper_base.dart';
import 'config.dart';

// BangBet Nigeria – bangbet.com API
class BangBetScraper extends ScraperBase {
  BangBetScraper() : super(bookmakerById('bangbet')!);

  static const _sportIds = {'soccer':'1','basketball':'2','tennis':'13','volleyball':'91','hockey':'4','american_football':'15'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sid = _sportIds[sport]; if (sid == null) return [];
    try {
      final r = await get('/api/odds/sport/$sid', query: {'market': _mkt(market), 'count': '200', 'status': 'prematch'});
      final body = r.data;
      final events = body?['data']??body?['events']??body?['matches']??body?['result'];
      if (events is List) return _parse(events, sport, market);
      return _tryAlt(sid, sport, market);
    } catch (_) { return _tryAlt(_sportIds[sport]!, sport, market); }
  }

  Future<List<Map<String, dynamic>>> _tryAlt(String sid, String sport, String market) async {
    try {
      final r = await get('/api/v2/sports/$sid/events', query: {'marketType': _mkt(market), 'limit': '200'});
      final events = r.data?['events']??r.data?['data']; if (events is! List) return [];
      return _parse(events, sport, market);
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _parse(List events, String sport, String market) {
    final out = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final id=(ev['id']??ev['eventId']??ev['matchId']??'').toString();
      final home=(ev['homeTeam']??ev['home']??ev['homeName']??ev['team1']??ev['homeTeamName']??'').toString().trim();
      final away=(ev['awayTeam']??ev['away']??ev['awayName']??ev['team2']??ev['awayTeamName']??'').toString().trim();
      if (home.isEmpty||away.isEmpty) continue;
      final league=(ev['league']??ev['competition']??ev['leagueName']??ev['tournament']??ev['tournamentName']??'').toString();
      final mks=ev['markets']??ev['odds']??ev['bet']; if (mks==null) continue;
      final list = mks is List ? mks : [mks];
      for (final mk in list) {
        if (mk is! Map) continue;
        final sels=mk['selections']??mk['outcomes']??mk['odds']; if (sels is! List) continue;
        final Map<String,dynamic> outcomes={}; final Map<String,List<double>> ouLines={};
        for (final s in sels) {
          if (s is! Map) continue;
          final n=(s['name']??s['label']??s['type']??'').toString().toLowerCase().trim();
          final v=_d(s['price']??s['odds']??s['value']??s['odd']??s['coef']); if (v==null) continue;
          if (market=='1x2') { if (n.contains('home')||n=='1'||n=='w1') outcomes['Home']=v; else if (n.contains('draw')||n=='x') outcomes['Draw']=v; else if (n.contains('away')||n=='2'||n=='w2') outcomes['Away']=v; }
          else if (market=='moneyline'||market=='winner') { if (n.contains('home')||n=='1') outcomes['Home']=v; else if (n.contains('away')||n=='2') outcomes['Away']=v; }
          else if (market=='over_under') { final m=RegExp(r'[\d.]+').allMatches(n).map((x)=>x.group(0)!).where((s)=>double.tryParse(s)!=null).toList(); final l=m.isNotEmpty?m.first:'2.5'; ouLines.putIfAbsent(l,()=>[0.0,0.0]); if (n.contains('over')) ouLines[l]![0]=v; else if (n.contains('under')) ouLines[l]![1]=v; }
          else if (market=='double_chance') { if (n.contains('1x')) outcomes['1X']=v; else if (n.contains('x2')) outcomes['X2']=v; else if (n.contains('12')) outcomes['12']=v; }
          else if (market=='btts') { if (n.contains('yes')||n.contains('gg')) outcomes['Yes']=v; else if (n.contains('no')||n.contains('ng')) outcomes['No']=v; }
        }
        if (market=='over_under') { for (final e in ouLines.entries) { if (e.value[0]>1&&e.value[1]>1) out.add({'id':'${id}_ou_${e.key}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':'Over/Under ${e.key}','outcomes':{'Over':e.value[0],'Under':e.value[1]}}); } }
        else if (outcomes.length>=2) out.add({'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':outcomes});
      }
    }
    return out;
  }

  String _mkt(String m) { switch(m) { case '1x2': return '1X2'; case 'over_under': return 'OU'; case 'double_chance': return 'DC'; case 'btts': return 'GG'; default: return m; } }
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
