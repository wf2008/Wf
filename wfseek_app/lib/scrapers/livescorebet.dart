import 'scraper_base.dart';
import 'config.dart';

// LiveScore Bet – livescorebet.com (Kambi-powered platform)
class LiveScoreBetScraper extends ScraperBase {
  LiveScoreBetScraper() : super(bookmakerById('livescorebet')!);

  static const _sportIds = {'soccer':'1000093190','basketball':'1000093193','tennis':'1000093194','volleyball':'1000093205','hockey':'1000093192','american_football':'1000093209'};
  static const _marketIds = {'1x2':'2_1','over_under':'2_16','double_chance':'2_7','btts':'2_34','moneyline':'2_1','winner':'2_1'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportId = _sportIds[sport]; if (sportId == null) return [];
    final marketId = _marketIds[market]; if (marketId == null) return [];
    try {
      // Kambi REST API
      final r = await get(
        'https://eu-offering-api.kambicdn.com/offering/v2018/livescorebet/listView/event.json',
        query: {'lang': 'en_GB', 'market': 'GB', 'client_id': '2', 'channel_id': '1', 'ncid': DateTime.now().millisecondsSinceEpoch.toString(), 'sport': sportId, 'categoryGroup': 'COMBINED', 'displayDefault': 'true', 'range': '0,200', 'betOfferTypes': marketId},
      );
      final events = r.data?['events']??r.data?['result']; if (events is! List) return _tryDirect(sportId, marketId, sport, market);
      return _parseKambi(events, sport, market);
    } catch (_) { return _tryDirect(sportId!, marketId!, sport, market); }
  }

  Future<List<Map<String, dynamic>>> _tryDirect(String sportId, String marketId, String sport, String market) async {
    try {
      final r = await get('/api/events', query: {'sport': sport, 'market': _mkt(market), 'count': '200', 'status': 'upcoming'});
      final events = r.data?['events']??r.data?['data']; if (events is! List) return [];
      return _parse(events, sport, market);
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _parseKambi(List events, String sport, String market) {
    final out = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final event = ev['event']??ev; if (event is! Map) continue;
      final home=(event['homeName']??event['home']??'').toString().trim();
      final away=(event['awayName']??event['away']??'').toString().trim();
      if (home.isEmpty||away.isEmpty) continue;
      final id=(event['id']??'').toString(); final league=(event['path']?.last?['name']??event['groupName']??event['league']??'').toString();
      final betOffers = ev['betOffers']??ev['markets']; if (betOffers is! List) continue;
      for (final offer in betOffers) {
        if (offer is! Map) continue;
        final outcomes = offer['outcomes']??offer['selections']; if (outcomes is! List) continue;
        final Map<String,dynamic> parsed={}; final Map<String,List<double>> ouLines={};
        for (final o in outcomes) {
          if (o is! Map) continue;
          final label=(o['label']??o['type']??o['name']??'').toString().toLowerCase().trim();
          final odds=_d(o['odds']!=null ? o['odds']/1000.0 : o['price']??o['decimalOdds']); if (odds==null) continue;
          if (market=='1x2') { if (label.contains('home')||label=='1'||label=='win1') parsed['Home']=odds; else if (label.contains('draw')||label=='x') parsed['Draw']=odds; else if (label.contains('away')||label=='2'||label=='win2') parsed['Away']=odds; }
          else if (market=='moneyline'||market=='winner') { if (label.contains('home')||label=='1') parsed['Home']=odds; else if (label.contains('away')||label=='2') parsed['Away']=odds; }
          else if (market=='over_under') { final line=o['line']!=null?(o['line']/1000.0).toStringAsFixed(1):(RegExp(r'[\d.]+').firstMatch(label)?.group(0)??'2.5'); ouLines.putIfAbsent(line,()=>[0.0,0.0]); if (label.contains('over')) ouLines[line]![0]=odds; else if (label.contains('under')) ouLines[line]![1]=odds; }
          else if (market=='btts') { if (label.contains('yes')) parsed['Yes']=odds; else if (label.contains('no')) parsed['No']=odds; }
        }
        if (market=='over_under') { for (final e in ouLines.entries) { if (e.value[0]>1&&e.value[1]>1) out.add({'id':'${id}_ou_${e.key}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':'Over/Under ${e.key}','outcomes':{'Over':e.value[0],'Under':e.value[1]}}); } }
        else if (parsed.length>=2) out.add({'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':parsed});
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _parse(List events, String sport, String market) {
    final out = <Map<String, dynamic>>[];
    for (final ev in events) {
      if (ev is! Map) continue;
      final id=(ev['id']??ev['eventId']??'').toString();
      final home=(ev['homeTeam']??ev['home']??'').toString().trim();
      final away=(ev['awayTeam']??ev['away']??'').toString().trim();
      if (home.isEmpty||away.isEmpty) continue;
      final league=(ev['league']??ev['competition']??ev['tournament']??'').toString();
      final mks=ev['markets']??ev['odds']; if (mks==null) continue;
      final list = mks is List ? mks : [mks];
      for (final mk in list) {
        if (mk is! Map) continue;
        final sels=mk['outcomes']??mk['selections']??mk['odds']; if (sels is! List) continue;
        final Map<String,dynamic> outcomes={}; final Map<String,List<double>> ouLines={};
        for (final s in sels) {
          if (s is! Map) continue;
          final n=(s['name']??s['label']??'').toString().toLowerCase().trim();
          final v=_d(s['price']??s['odds']??s['value']); if (v==null) continue;
          if (market=='1x2') { if (n.contains('home')||n=='1') outcomes['Home']=v; else if (n.contains('draw')||n=='x') outcomes['Draw']=v; else if (n.contains('away')||n=='2') outcomes['Away']=v; }
          else if (market=='moneyline'||market=='winner') { if (n.contains('home')||n=='1') outcomes['Home']=v; else if (n.contains('away')||n=='2') outcomes['Away']=v; }
          else if (market=='over_under') { final m=RegExp(r'[\d.]+').allMatches(n).map((x)=>x.group(0)!).where((s)=>double.tryParse(s)!=null).toList(); final l=m.isNotEmpty?m.first:'2.5'; ouLines.putIfAbsent(l,()=>[0.0,0.0]); if (n.contains('over')) ouLines[l]![0]=v; else if (n.contains('under')) ouLines[l]![1]=v; }
          else if (market=='btts') { if (n.contains('yes')) outcomes['Yes']=v; else if (n.contains('no')) outcomes['No']=v; }
        }
        if (market=='over_under') { for (final e in ouLines.entries) { if (e.value[0]>1&&e.value[1]>1) out.add({'id':'${id}_ou_${e.key}','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':'Over/Under ${e.key}','outcomes':{'Over':e.value[0],'Under':e.value[1]}}); } }
        else if (outcomes.length>=2) out.add({'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':market,'outcomes':outcomes});
      }
    }
    return out;
  }

  String _mkt(String m) { switch(m) { case '1x2': return 'match_result'; case 'over_under': return 'total_goals'; case 'double_chance': return 'double_chance'; case 'btts': return 'btts'; default: return m; } }
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
}
