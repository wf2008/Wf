import 'scraper_base.dart';
import 'config.dart';

// Pinnacle – documented public API at api.pinnacle.com
// Soccer=29, Basketball=4, Tennis=33, Volleyball=91, Ice Hockey=19, American Football=15
class PinnacleScraper extends ScraperBase {
  PinnacleScraper() : super(bookmakerById('pinnacle')!);

  static const _sportIds = {'soccer':29,'basketball':4,'tennis':33,'volleyball':91,'hockey':19,'american_football':15};

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportId = _sportIds[sport]; if (sportId == null) return [];
    try {
      // Step 1: get fixtures
      final fixResp = await get(
        'https://api.pinnacle.com/v1/fixtures',
        query: {'sportId': sportId.toString(), 'since': '0', 'isLive': '0'},
      );
      final leagues = fixResp.data?['league'];
      if (leagues is! List) return [];

      final leagueEventMap = <int, Map<int, Map<String,String>>>{};
      for (final lg in leagues) {
        if (lg is! Map) continue;
        final lgId = lg['id'] is int ? lg['id'] as int : int.tryParse('${lg['id']}') ?? 0;
        final lgName = (lg['name'] ?? '').toString();
        final events = lg['events'];
        if (events is! List) continue;
        for (final ev in events) {
          if (ev is! Map) continue;
          final evId = ev['id'] is int ? ev['id'] as int : int.tryParse('${ev['id']}') ?? 0;
          leagueEventMap.putIfAbsent(lgId, () => {})[evId] = {
            'league': lgName,
            'home': (ev['home'] ?? '').toString(),
            'away': (ev['away'] ?? '').toString(),
          };
        }
      }
      if (leagueEventMap.isEmpty) return [];

      // Step 2: get odds for all leagues in batches
      final leagueIds = leagueEventMap.keys.take(10).toList();
      final oddsResp = await get(
        'https://api.pinnacle.com/v2/odds',
        query: {
          'sportId': sportId.toString(),
          'leagueIds': leagueIds.join(','),
          'oddsFormat': 'decimal',
          'since': '0',
        },
      );

      final oddsLeagues = oddsResp.data?['leagues'];
      if (oddsLeagues is! List) return [];
      final out = <Map<String, dynamic>>[];

      for (final lg in oddsLeagues) {
        if (lg is! Map) continue;
        final lgId = lg['id'] is int ? lg['id'] as int : int.tryParse('${lg['id']}') ?? 0;
        final eventOdds = lg['events'];
        if (eventOdds is! List) continue;

        for (final eo in eventOdds) {
          if (eo is! Map) continue;
          final evId = eo['id'] is int ? eo['id'] as int : int.tryParse('${eo['id']}') ?? 0;
          final evMeta = leagueEventMap[lgId]?[evId];
          if (evMeta == null) continue;
          final home = evMeta['home'] ?? ''; final away = evMeta['away'] ?? '';
          if (home.isEmpty || away.isEmpty) continue;
          final league = evMeta['league'] ?? '';

          final periods = eo['periods'];
          if (periods is! List) continue;
          final fulltime = periods.firstWhere((p) => p is Map && p['lineId'] == 0, orElse: () => null);
          if (fulltime is! Map) continue;

          switch (market) {
            case '1x2':
              final ms = fulltime['moneyline'];
              if (ms is Map) {
                final h = _d(ms['home']); final dr = _d(ms['draw']); final a = _d(ms['away']);
                if (h != null && a != null) {
                  final outcomes = dr != null ? {'Home':h,'Draw':dr,'Away':a} : {'Home':h,'Away':a};
                  out.add(_ev('$evId', home, away, league, sport, market, market, outcomes));
                }
              }
              break;
            case 'moneyline': case 'winner':
              final ms = fulltime['moneyline'];
              if (ms is Map) {
                final h = _d(ms['home']); final a = _d(ms['away']);
                if (h != null && a != null) out.add(_ev('$evId', home, away, league, sport, market, market, {'Home':h,'Away':a}));
              }
              break;
            case 'over_under':
              final totals = fulltime['totals'];
              if (totals is List) {
                for (final t in totals) {
                  if (t is! Map) continue;
                  final line = (t['points'] is num) ? (t['points'] as num).toStringAsFixed(1) : '2.5';
                  final o = _d(t['over']); final u = _d(t['under']);
                  if (o != null && u != null) out.add(_ev('${evId}_ou_$line', home, away, league, sport, 'over_under', 'Over/Under $line', {'Over':o,'Under':u}));
                }
              }
              break;
          }
        }
      }
      return out;
    } catch (_) { return []; }
  }

  double? _d(dynamic v) { if (v == null) return null; final d = v is num ? v.toDouble() : double.tryParse('$v'); return (d != null && d > 1.0) ? d : null; }
  Map<String, dynamic> _ev(String id, String home, String away, String league, String sport, String market, String detail, Map<String, dynamic> outcomes) =>
      {'id':'${id}_$market','home_team':home,'away_team':away,'league':league,'category':'','sport':sport,'market':market,'market_detail':detail,'outcomes':outcomes};
}
