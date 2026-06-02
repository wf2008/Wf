import 'package:dio/dio.dart';
import 'scraper_base.dart';
import 'config.dart';

// Stake.com – GraphQL API
class StakeScraper extends ScraperBase {
  StakeScraper() : super(bookmakerById('stake')!);

  static const _sportSlugs = {'soccer':'soccer','basketball':'basketball','tennis':'tennis','volleyball':'volleyball','hockey':'ice_hockey','american_football':'american_football'};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final slug = _sportSlugs[sport]; if (slug == null) return [];
    try {
      final query = '''
        query FixtureList(\$sport: String!, \$limit: Int!) {
          sportFixtures(sport: \$sport, limit: \$limit, status: "upcoming") {
            id slug name status
            tournament { name }
            competitors { name type }
            odds {
              moneyline { home draw away }
              totals { line over under }
              doubleChance { homeOrDraw drawOrAway homeOrAway }
              bothTeamsToScore { yes no }
            }
          }
        }
      ''';
      final r = await get('/graphql', query: null);
      // Use post for GraphQL
      final dio = Dio(BaseOptions(headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}));
      final resp = await dio.post('https://stake.com/_api/graphql',
          data: {'operationName': 'FixtureList', 'query': query, 'variables': {'sport': slug, 'limit': 100}});
      final fixtures = resp.data?['data']?['sportFixtures'];
      if (fixtures is! List) return [];
      final out = <Map<String, dynamic>>[];
      for (final f in fixtures) {
        if (f is! Map) continue;
        final comps = f['competitors'];
        if (comps is! List || comps.length < 2) continue;
        final home = (comps.firstWhere((c) => c is Map && (c['type']??'').toString().toLowerCase()=='home', orElse: () => comps[0])['name'] ?? '').toString().trim();
        final away = (comps.firstWhere((c) => c is Map && (c['type']??'').toString().toLowerCase()=='away', orElse: () => comps[1])['name'] ?? '').toString().trim();
        if (home.isEmpty || away.isEmpty) continue;
        final id = (f['id'] ?? f['slug'] ?? '').toString();
        final league = (f['tournament']?['name'] ?? '').toString();
        final odds = f['odds'];
        if (odds is! Map) continue;
        switch (market) {
          case '1x2':
            final ml = odds['moneyline']; if (ml is! Map) break;
            final h = _d(ml['home']); final dr = _d(ml['draw']); final a = _d(ml['away']);
            if (h != null && dr != null && a != null) out.add(_ev(id, home, away, league, sport, market, market, {'Home':h,'Draw':dr,'Away':a}));
            break;
          case 'moneyline': case 'winner':
            final ml = odds['moneyline']; if (ml is! Map) break;
            final h = _d(ml['home']); final a = _d(ml['away']);
            if (h != null && a != null) out.add(_ev(id, home, away, league, sport, market, market, {'Home':h,'Away':a}));
            break;
          case 'over_under':
            final totals = odds['totals'];
            if (totals is List) {
              for (final t in totals) {
                if (t is! Map) continue;
                final line = (t['line'] is num) ? (t['line'] as num).toStringAsFixed(1) : '2.5';
                final o = _d(t['over']); final u = _d(t['under']);
                if (o != null && u != null) out.add(_ev('${id}_ou_$line', home, away, league, sport, 'over_under', 'Over/Under $line', {'Over':o,'Under':u}));
              }
            } else if (totals is Map) {
              final line = (totals['line'] is num) ? (totals['line'] as num).toStringAsFixed(1) : '2.5';
              final o = _d(totals['over']); final u = _d(totals['under']);
              if (o != null && u != null) out.add(_ev('${id}_ou_$line', home, away, league, sport, 'over_under', 'Over/Under $line', {'Over':o,'Under':u}));
            }
            break;
          case 'double_chance':
            final dc = odds['doubleChance']; if (dc is! Map) break;
            final ox = _d(dc['homeOrDraw']); final xt = _d(dc['drawOrAway']); final ot = _d(dc['homeOrAway']);
            if (ox != null && xt != null && ot != null) out.add(_ev(id, home, away, league, sport, market, market, {'1X':ox,'X2':xt,'12':ot}));
            break;
          case 'btts':
            final btts = odds['bothTeamsToScore']; if (btts is! Map) break;
            final y = _d(btts['yes']); final n = _d(btts['no']);
            if (y != null && n != null) out.add(_ev(id, home, away, league, sport, market, market, {'Yes':y,'No':n}));
            break;
        }
      }
      return out;
    } catch (_) { return []; }
  }

  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
  Map<String, dynamic> _ev(String id, String home, String away, String league, String sport, String market, String detail, Map<String, dynamic> outcomes) =>
      {'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':detail,'outcomes':outcomes};
}
