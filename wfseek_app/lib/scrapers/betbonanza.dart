import 'scraper_base.dart';
import 'config.dart';

class BetBonanzaScraper extends ScraperBase {
  BetBonanzaScraper() : super(bookmakerById('betbonanza')!);

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final ep = endpointFor(sport, market);
    if (ep == null) return [];
    // TODO: Implement actual parsing for BetBonanza.
    // Steps:
    //   1) final resp = await get(ep);
    //   2) final data = resp.data;
    //   3) Iterate events, build normalized maps.
    return <Map<String, dynamic>>[];
  }
}
