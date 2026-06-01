import 'team_matcher.dart';

class ArbOutcome {
  final String label;
  final String bookmaker;
  final double odds;
  ArbOutcome({required this.label, required this.bookmaker, required this.odds});

  Map<String, dynamic> toMap() => {
        'bookmaker': bookmaker,
        'odds': odds,
      };
}

class ArbOpportunity {
  final String id;
  final String sport;
  final String market;
  final String marketDetail;
  final String league;
  final String category;
  final String homeTeam;
  final String awayTeam;
  final double profit; // percent
  final Map<String, ArbOutcome> outcomes;
  final Map<String, double> stakes;

  ArbOpportunity({
    required this.id,
    required this.sport,
    required this.market,
    required this.marketDetail,
    required this.league,
    required this.category,
    required this.homeTeam,
    required this.awayTeam,
    required this.profit,
    required this.outcomes,
    required this.stakes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sport': sport,
        'market': market,
        'market_detail': marketDetail,
        'league': league,
        'category': category,
        'home_team': homeTeam,
        'away_team': awayTeam,
        'profit': profit,
        'outcomes': {for (final e in outcomes.entries) e.key: e.value.toMap()},
        'stakes': stakes,
      };
}

class ArbDetector {
  static const _epsilon = 0.999;

  bool isArb(List<double> odds) {
    if (odds.length < 2) return false;
    var inv = 0.0;
    for (final o in odds) {
      if (o <= 1.0) return false;
      inv += 1.0 / o;
    }
    return inv < _epsilon;
  }

  /// Standard surebet stake calculation.
  Map<String, double> calculateStakes(
    Map<String, double> oddsByLabel,
    double totalInvestment,
  ) {
    var inv = 0.0;
    oddsByLabel.forEach((_, o) => inv += 1.0 / o);
    final stakes = <String, double>{};
    if (inv <= 0) return stakes;
    oddsByLabel.forEach((label, o) {
      stakes[label] = totalInvestment * (1.0 / o) / inv;
    });
    return stakes;
  }

  /// For each matched group, find the best odds per outcome label and check arb.
  List<ArbOpportunity> detectArbs(
    List<MatchedGroup> groups, {
    double totalInvestment = 1000.0,
  }) {
    final out = <ArbOpportunity>[];
    for (final g in groups) {
      // Collect outcome label -> (bookmaker, bestOdds)
      final best = <String, ArbOutcome>{};
      g.entriesByBookmaker.forEach((bmId, event) {
        final outcomes = event['outcomes'];
        if (outcomes is! Map) return;
        outcomes.forEach((label, oddsRaw) {
          final odds = (oddsRaw is num) ? oddsRaw.toDouble() : double.tryParse('$oddsRaw') ?? 0.0;
          if (odds <= 1.0) return;
          final cur = best[label.toString()];
          if (cur == null || odds > cur.odds) {
            best[label.toString()] = ArbOutcome(
              label: label.toString(),
              bookmaker: bmId,
              odds: odds,
            );
          }
        });
      });
      if (best.length < 2) continue;
      // Sanity: for 1x2 we need 3, for 2-way we need 2.
      final expected = _expectedOutcomeCount(g.market);
      if (expected != null && best.length != expected) continue;

      final oddsList = best.values.map((o) => o.odds).toList();
      if (!isArb(oddsList)) continue;

      var inv = 0.0;
      for (final o in oddsList) {
        inv += 1.0 / o;
      }
      final profit = (1.0 / inv - 1.0) * 100.0;

      final stakes = calculateStakes(
        {for (final e in best.entries) e.key: e.value.odds},
        totalInvestment,
      );

      final id = [
        g.sport,
        g.market,
        g.marketDetail,
        g.homeTeam,
        g.awayTeam,
      ].join('_').toLowerCase().replaceAll(RegExp(r'\s+'), '');

      out.add(ArbOpportunity(
        id: id,
        sport: g.sport,
        market: g.market,
        marketDetail: g.marketDetail,
        league: g.league,
        category: g.category,
        homeTeam: g.homeTeam,
        awayTeam: g.awayTeam,
        profit: double.parse(profit.toStringAsFixed(2)),
        outcomes: best,
        stakes: {for (final e in stakes.entries) e.key: double.parse(e.value.toStringAsFixed(2))},
      ));
    }
    return out;
  }

  int? _expectedOutcomeCount(String market) {
    switch (market) {
      case '1x2':
        return 3;
      case 'double_chance':
        return 3;
      case 'btts':
      case 'over_under':
      case 'moneyline':
      case 'winner':
        return 2;
    }
    return null;
  }
}
