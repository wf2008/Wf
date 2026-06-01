import 'scraper_base.dart';
import 'config.dart';

class MaxBetScraper extends ScraperBase {
  MaxBetScraper() : super(bookmakerById('maxbet')!);

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final ep = endpointFor(sport, market);
    if (ep == null) return [];
    // TODO: Implement actual parsing for MaxBet.
    // Steps:
    //   1) final resp = await get(ep);
    //   2) final data = resp.data;
    //   3) Iterate events, build normalized maps:
    //      {
    //        'id': eventId,
    //        'home_team': home,
    //        'away_team': away,
    //        'league': league ?? '',
    //        'category': category ?? '',
    //        'sport': sport,
    //        'market': market,
    //        'market_detail': market == 'over_under' ? 'Over/Under X.5' : market,
    //        'outcomes': { 'Home': h, 'Draw': d, 'Away': a },
    //      }
    //   4) For 'over_under', emit one map per line.
    return <Map<String, dynamic>>[];
  }
}
