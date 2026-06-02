import 'scraper_base.dart';
import 'config.dart';

// 1xBet LineFeed API (same platform as 22bet, betwinner — only domain differs)
// Sport IDs: soccer=1, basketball=2, tennis=5, volleyball=16, hockey=4, american_football=9
class OneXBetScraper extends ScraperBase {
  OneXBetScraper() : super(bookmakerById('1xbet')!);

  static const _sportIds = {'soccer':'1','basketball':'2','tennis':'5','volleyball':'16','hockey':'4','american_football':'9'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sid = _sportIds[sport]; if (sid == null) return [];
    try {
      switch (market) {
        case '1x2': case 'moneyline': case 'winner': return await _get1x2(sid, sport, market);
        case 'over_under': return await _getOU(sid, sport);
        case 'double_chance': return await _getDC(sid, sport);
        case 'btts': return await _getBTTS(sid, sport);
        default: return [];
      }
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> _get1x2(String sid, String sport, String market) async {
    final r = await get('/LineFeed/Get1x2_3Way',
        query: {'sportId': sid, 'champ': '0', 'count': '200', 'lng': 'en', 'tf': '2200000', 'tz': '1', 'mode': '1'});
    final vals = r.data?['Value'];
    if (vals is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in vals) {
      if (e is! Map) continue;
      final home = _s(e['Team1']); final away = _s(e['Team2']);
      if (home.isEmpty || away.isEmpty) continue;
      final id = _s(e['Id']); final league = _s(e['League'] ?? e['ChampName']);
      if (sport == 'soccer' && market == '1x2') {
        final h = _d(e['Coff1'] ?? e['O1']); final dr = _d(e['CoffX'] ?? e['OX']); final a = _d(e['Coff2'] ?? e['O2']);
        if (h != null && dr != null && a != null) out.add(_ev(id, home, away, league, sport, market, market, {'Home':h,'Draw':dr,'Away':a}));
      } else {
        final h = _d(e['Coff1'] ?? e['O1']); final a = _d(e['Coff2'] ?? e['O2']);
        if (h != null && a != null) out.add(_ev(id, home, away, league, sport, market, market, {'Home':h,'Away':a}));
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _getOU(String sid, String sport) async {
    final r = await get('/LineFeed/Get1x2_3Way',
        query: {'sportId': sid, 'champ': '0', 'count': '50', 'lng': 'en', 'tf': '2200000', 'tz': '1', 'mode': '1'});
    final vals = r.data?['Value'];
    if (vals is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in (vals as List).take(20)) {
      if (e is! Map) continue;
      final id = _s(e['Id']); final home = _s(e['Team1']); final away = _s(e['Team2']);
      if (home.isEmpty || away.isEmpty || id.isEmpty) continue;
      final league = _s(e['League'] ?? e['ChampName']);
      try {
        final gr = await get('/LineFeed/GetGameZip', query: {'id': id, 'lng': 'en', 'cfrom': 'ballhead'});
        final markets = gr.data?['Value']?['GE'];
        if (markets is! List) continue;
        for (final mk in markets) {
          if (mk is! Map) continue;
          final odds = mk['ME'];
          if (odds is! List) continue;
          final overItems = (odds).where((o) => o is Map && (o['MN']?.toString() ?? '').toLowerCase().contains('over')).toList();
          final underItems = (odds).where((o) => o is Map && (o['MN']?.toString() ?? '').toLowerCase().contains('under')).toList();
          for (final ov in overItems) {
            if (ov is! Map) continue;
            final name = (ov['MN'] ?? '').toString();
            final line = RegExp(r'[\d.]+').allMatches(name).map((m) => m.group(0)).firstWhere((s) => s != null && double.tryParse(s!) != null, orElse: () => '2.5')!;
            final overOdds = _d(ov['MO'] ?? ov['Coef']);
            final underMatch = underItems.where((u) => u is Map && (u['MN'] ?? '').toString().contains(line)).toList();
            final underOdds = underMatch.isNotEmpty ? _d(underMatch.first['MO'] ?? underMatch.first['Coef']) : null;
            if (overOdds != null && underOdds != null) {
              out.add(_ev('${id}_ou_$line', home, away, league, sport, 'over_under', 'Over/Under $line', {'Over': overOdds, 'Under': underOdds}));
            }
          }
        }
      } catch (_) { continue; }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _getDC(String sid, String sport) async {
    final r = await get('/LineFeed/Get1x2_3Way',
        query: {'sportId': sid, 'champ': '0', 'count': '200', 'lng': 'en', 'tf': '2200000', 'tz': '1', 'mode': '4'});
    final vals = r.data?['Value'];
    if (vals is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in vals) {
      if (e is! Map) continue;
      final home = _s(e['Team1']); final away = _s(e['Team2']);
      if (home.isEmpty || away.isEmpty) continue;
      final id = _s(e['Id']); final league = _s(e['League']);
      final ox = _d(e['O1X'] ?? e['Coff1X']); final xt = _d(e['OX2'] ?? e['CoffX2']); final ot = _d(e['O12'] ?? e['Coff12']);
      if (ox != null && xt != null && ot != null) out.add(_ev(id, home, away, league, sport, 'double_chance', 'double_chance', {'1X':ox,'X2':xt,'12':ot}));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _getBTTS(String sid, String sport) async {
    final r = await get('/LineFeed/Get1x2_3Way',
        query: {'sportId': sid, 'champ': '0', 'count': '200', 'lng': 'en', 'tf': '2200000', 'tz': '1', 'mode': '7'});
    final vals = r.data?['Value'];
    if (vals is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in vals) {
      if (e is! Map) continue;
      final home = _s(e['Team1']); final away = _s(e['Team2']);
      if (home.isEmpty || away.isEmpty) continue;
      final id = _s(e['Id']); final league = _s(e['League']);
      final y = _d(e['OYes'] ?? e['Yes']); final n = _d(e['ONo'] ?? e['No']);
      if (y != null && n != null) out.add(_ev(id, home, away, league, sport, 'btts', 'btts', {'Yes':y,'No':n}));
    }
    return out;
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
  Map<String, dynamic> _ev(String id, String home, String away, String league, String sport, String market, String detail, Map<String, dynamic> outcomes) =>
      {'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':detail,'outcomes':outcomes};
}
