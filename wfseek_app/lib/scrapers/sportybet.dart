import 'scraper_base.dart';
import 'config.dart';

// SportyBet NG real API
// Sport IDs: soccer=sr:sport:1, basketball=sr:sport:2, tennis=sr:sport:5,
//            volleyball=sr:sport:23, hockey=sr:sport:4, american_football=sr:sport:16
// Market IDs: 1=1X2, 7=Double Chance, 18=BTTS, 6=Over/Under, 3=Moneyline, 219=Winner
class SportyBetScraper extends ScraperBase {
  SportyBetScraper() : super(bookmakerById('sportybet')!);

  static const _sportIds = {
    'soccer': 'sr:sport:1',
    'basketball': 'sr:sport:2',
    'tennis': 'sr:sport:5',
    'volleyball': 'sr:sport:23',
    'hockey': 'sr:sport:4',
    'american_football': 'sr:sport:16',
  };

  static const _marketIds = {
    '1x2': '1',
    'double_chance': '7',
    'btts': '18',
    'over_under': '6',
    'moneyline': '3',
    'winner': '219',
  };

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final sportId = _sportIds[sport];
    final marketId = _marketIds[market];
    if (sportId == null || marketId == null) return [];

    try {
      final resp = await get(
        'https://www.sportybet.com/api/ng/factsCenter/tournamentsWithMarkets',
        query: {
          'sportId': sportId,
          'marketId': marketId,
          'tSize': '500',
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final body = resp.data;
      if (body == null) return [];
      final data = body['data'];
      if (data == null) return [];
      final tournaments = data['tournaments'];
      if (tournaments is! List) return [];

      final results = <Map<String, dynamic>>[];

      for (final t in tournaments) {
        if (t is! Map) continue;
        final leagueName = (t['tournamentName'] ?? t['name'] ?? '').toString();
        final events = t['events'];
        if (events is! List) continue;

        for (final ev in events) {
          if (ev is! Map) continue;
          final id = (ev['id'] ?? ev['eventId'] ?? '').toString();
          final home = (ev['homeTeamName'] ?? ev['home'] ?? '').toString().trim();
          final away = (ev['awayTeamName'] ?? ev['away'] ?? '').toString().trim();
          if (home.isEmpty || away.isEmpty) continue;

          final markets = ev['markets'];
          if (markets is! List) continue;

          for (final mk in markets) {
            if (mk is! Map) continue;
            final selections = mk['selections'] ?? mk['odds'];
            if (selections is! List) continue;

            if (market == 'over_under') {
              // Group by line value
              final lines = <String, Map<String, dynamic>>{};
              for (final sel in selections) {
                if (sel is! Map) continue;
                final name = (sel['name'] ?? '').toString().toLowerCase();
                final oddsRaw = sel['odds'];
                final odds = oddsRaw is num
                    ? oddsRaw.toDouble()
                    : double.tryParse('$oddsRaw') ?? 0.0;
                if (odds <= 1.0) continue;
                // name format: "Over 2.5" or "Under 2.5"
                final parts = name.split(' ');
                if (parts.length < 2) continue;
                final label = parts[0]; // Over / Under
                final line = parts[1];  // 2.5
                lines.putIfAbsent(line, () => {});
                lines[line]![label == 'over' ? 'Over' : 'Under'] = odds;
              }
              for (final entry in lines.entries) {
                final o = entry.value['Over'];
                final u = entry.value['Under'];
                if (o == null || u == null) continue;
                results.add({
                  'id': '${id}_ou_${entry.key}',
                  'home_team': home,
                  'away_team': away,
                  'league': leagueName,
                  'category': '',
                  'sport': sport,
                  'market': market,
                  'market_detail': 'Over/Under ${entry.key}',
                  'outcomes': {'Over': o, 'Under': u},
                });
              }
            } else {
              final outcomes = <String, dynamic>{};
              for (final sel in selections) {
                if (sel is! Map) continue;
                final name = (sel['name'] ?? '').toString();
                final oddsRaw = sel['odds'];
                final odds = oddsRaw is num
                    ? oddsRaw.toDouble()
                    : double.tryParse('$oddsRaw') ?? 0.0;
                if (odds <= 1.0) continue;
                final label = _normalizeLabel(name, market);
                if (label.isNotEmpty) outcomes[label] = odds;
              }
              if (outcomes.length >= 2) {
                results.add({
                  'id': '${id}_${market}',
                  'home_team': home,
                  'away_team': away,
                  'league': leagueName,
                  'category': '',
                  'sport': sport,
                  'market': market,
                  'market_detail': market,
                  'outcomes': outcomes,
                });
              }
            }
          }
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  String _normalizeLabel(String name, String market) {
    final n = name.toLowerCase().trim();
    switch (market) {
      case '1x2':
        if (n == 'home' || n == '1' || n == 'w1') return 'Home';
        if (n == 'draw' || n == 'x' || n == 'draw') return 'Draw';
        if (n == 'away' || n == '2' || n == 'w2') return 'Away';
        break;
      case 'double_chance':
        if (n == '1x' || n == 'home or draw') return '1X';
        if (n == '12' || n == 'home or away') return '12';
        if (n == 'x2' || n == 'draw or away') return 'X2';
        break;
      case 'btts':
        if (n == 'yes' || n == 'gg') return 'Yes';
        if (n == 'no' || n == 'ng') return 'No';
        break;
      case 'moneyline':
      case 'winner':
        if (n == 'home' || n == '1' || n == 'w1' || n == 'player 1') return 'Home';
        if (n == 'away' || n == '2' || n == 'w2' || n == 'player 2') return 'Away';
        break;
    }
    return name.isNotEmpty ? name : '';
  }
}
