import 'scraper_base.dart';
import 'config.dart';

class SupabetScraper extends ScraperBase {
  SupabetScraper() : super(bookmakerById('supabet')!);

  @override
  Future<List<Map<String, dynamic>>> getOdds(String sport, String market) async {
    final ep = endpointFor(sport, market);
    if (ep == null) return [];
    // TODO: Implement actual parsing for Supabet.
    // Steps:
    //   1) final resp = await get(ep);
    //   2) final data = resp.data;
    //   3) Iterate events, build normalized maps.
    return <Map<String, dynamic>>[];
  }
}
