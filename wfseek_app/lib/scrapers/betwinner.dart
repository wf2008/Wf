import 'scraper_base.dart';
import 'config.dart';

// BetWinner – same LineFeed platform as 1xBet, domain betwinner.com
class BetWinnerScraper extends ScraperBase {
  BetWinnerScraper() : super(bookmakerById('betwinner')!);

  static const _sportIds = {'soccer':'1','basketball':'2','tennis':'5','volleyball':'16','hockey':'4','american_football':'9'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sid = _sportIds[sport]; if (sid == null) return [];
    try {
      final mode = market == 'double_chance' ? '4' : market == 'btts' ? '7' : '1';
      final r = await get('/LineFeed/Get1x2_3Way',
          query: {'sportId': sid, 'champ': '0', 'count': '200', 'lng': 'en', 'tf': '2200000', 'tz': '1', 'mode': mode});
      final vals = r.data?['Value'];
      if (vals is! List) return [];
      final out = <Map<String, dynamic>>[];
      for (final e in vals) {
        if (e is! Map) continue;
        final home = _s(e['Team1']); final away = _s(e['Team2']);
        if (home.isEmpty || away.isEmpty) continue;
        final id = _s(e['Id']); final league = _s(e['League'] ?? e['ChampName']);
        switch (market) {
          case '1x2':
            final h = _d(e['Coff1'] ?? e['O1']); final dr = _d(e['CoffX'] ?? e['OX']); final a = _d(e['Coff2'] ?? e['O2']);
            if (h != null && dr != null && a != null) out.add(_ev(id, home, away, league, sport, market, market, {'Home':h,'Draw':dr,'Away':a}));
            break;
          case 'moneyline': case 'winner':
            final h = _d(e['Coff1'] ?? e['O1']); final a = _d(e['Coff2'] ?? e['O2']);
            if (h != null && a != null) out.add(_ev(id, home, away, league, sport, market, market, {'Home':h,'Away':a}));
            break;
          case 'double_chance':
            final ox = _d(e['O1X'] ?? e['Coff1X']); final xt = _d(e['OX2'] ?? e['CoffX2']); final ot = _d(e['O12'] ?? e['Coff12']);
            if (ox != null && xt != null && ot != null) out.add(_ev(id, home, away, league, sport, market, market, {'1X':ox,'X2':xt,'12':ot}));
            break;
          case 'btts':
            final y = _d(e['OYes'] ?? e['Yes']); final n = _d(e['ONo'] ?? e['No']);
            if (y != null && n != null) out.add(_ev(id, home, away, league, sport, market, market, {'Yes':y,'No':n}));
            break;
          case 'over_under':
            final h2 = _d(e['Coff1'] ?? e['O1']); final a2 = _d(e['Coff2'] ?? e['O2']);
            if (h2 != null && a2 != null) out.add(_ev('${id}_ou_2.5', home, away, league, sport, market, 'Over/Under 2.5', {'Over':h2,'Under':a2}));
            break;
        }
      }
      return out;
    } catch (_) { return []; }
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';
  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
  Map<String, dynamic> _ev(String id, String home, String away, String league, String sport, String market, String detail, Map<String, dynamic> outcomes) =>
      {'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':detail,'outcomes':outcomes};
}
