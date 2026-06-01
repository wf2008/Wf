/// Configuration of all bookmakers and supported sports/markets.

class BookmakerConfig {
  final String id;
  final String name;
  final String domain;
  final String baseUrl;
  final Map<String, Map<String, String>> endpoints; // sport -> market -> path
  final bool protected;
  final bool providesLeagueCategory;

  const BookmakerConfig({
    required this.id,
    required this.name,
    required this.domain,
    required this.baseUrl,
    required this.endpoints,
    this.protected = false,
    this.providesLeagueCategory = false,
  });
}

/// Sports supported by the network.
const List<String> sports = [
  'soccer',
  'basketball',
  'tennis',
  'volleyball',
  'hockey',
  'american_football',
];

/// Markets supported per sport.
const Map<String, List<String>> marketsBySport = {
  'soccer': ['1x2', 'over_under', 'double_chance', 'btts'],
  'basketball': ['moneyline', 'over_under'],
  'tennis': ['winner'],
  'volleyball': ['winner'],
  'hockey': ['moneyline'],
  'american_football': ['moneyline'],
};

Map<String, Map<String, String>> _defaultEndpoints() => {
      'soccer': {
        '1x2': '/api/odds/soccer/1x2',
        'over_under': '/api/odds/soccer/ou',
        'double_chance': '/api/odds/soccer/dc',
        'btts': '/api/odds/soccer/btts',
      },
      'basketball': {
        'moneyline': '/api/odds/basketball/ml',
        'over_under': '/api/odds/basketball/ou',
      },
      'tennis': {'winner': '/api/odds/tennis/winner'},
      'volleyball': {'winner': '/api/odds/volleyball/winner'},
      'hockey': {'moneyline': '/api/odds/hockey/ml'},
      'american_football': {'moneyline': '/api/odds/nfl/ml'},
    };

/// The 30 bookmakers (all accessible in Nigeria).
final List<BookmakerConfig> bookmakers = [
  // ── Core Nigerian bookmakers ──────────────────────────────────────────────
  BookmakerConfig(
    id: 'bet9ja', name: 'Bet9ja', domain: 'bet9ja.com',
    baseUrl: 'https://mobile.bet9ja.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'sportybet', name: 'SportyBet', domain: 'sportybet.com',
    baseUrl: 'https://www.sportybet.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'bangbet', name: 'BangBet', domain: 'bangbet.com',
    baseUrl: 'https://www.bangbet.com', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'msport', name: 'MSport', domain: 'msport.com',
    baseUrl: 'https://www.msport.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'maxbet', name: 'MaxBet', domain: 'maxbet.ng',
    baseUrl: 'https://www.maxbet.ng', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'betpawa', name: 'BetPawa', domain: 'betpawa.ng',
    baseUrl: 'https://www.betpawa.ng', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'nairabet', name: 'NairaBet', domain: 'nairabet.com',
    baseUrl: 'https://www.nairabet.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'merrybet', name: 'MerryBet', domain: 'merrybet.com',
    baseUrl: 'https://www.merrybet.com', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'accessbet', name: 'AccessBet', domain: 'accessbet.com',
    baseUrl: 'https://www.accessbet.com', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'winnerbet', name: 'WinnerBet', domain: 'winner.bet',
    baseUrl: 'https://www.winner.bet', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'betking', name: 'BetKing', domain: 'betking.com',
    baseUrl: 'https://www.betking.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'betway', name: 'Betway', domain: 'ng.betway.com',
    baseUrl: 'https://ng.betway.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'betano', name: 'Betano', domain: 'ng.betano.com',
    baseUrl: 'https://ng.betano.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),

  // ── International bookmakers accessible in Nigeria ─────────────────────
  BookmakerConfig(
    id: 'betwinner', name: 'BetWinner', domain: 'betwinner.com',
    baseUrl: 'https://betwinner.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: '22bet', name: '22Bet', domain: '22bet.com',
    baseUrl: 'https://22bet.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: '1xbet', name: '1xBet', domain: '1xbet.com',
    baseUrl: 'https://1xbet.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'bet365', name: 'bet365', domain: 'bet365.com',
    baseUrl: 'https://www.bet365.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'livescorebet', name: 'LiveScore Bet', domain: 'livescorebet.com',
    baseUrl: 'https://www.livescorebet.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'pinnacle', name: 'Pinnacle', domain: 'pinnacle.com',
    baseUrl: 'https://www.pinnacle.com', endpoints: _defaultEndpoints(),
    protected: false, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'cloudbet', name: 'Cloudbet', domain: 'cloudbet.com',
    baseUrl: 'https://www.cloudbet.com', endpoints: _defaultEndpoints(),
    protected: false, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'bcgame', name: 'BC.Game', domain: 'bc.game',
    baseUrl: 'https://bc.game', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'stake', name: 'Stake', domain: 'stake.com',
    baseUrl: 'https://stake.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),

  // ── Nigerian replacement bookmakers (replacing geo-restricted ones) ───────
  BookmakerConfig(
    id: 'parimatch', name: 'Parimatch NG', domain: 'parimatch.ng',
    baseUrl: 'https://parimatch.ng', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'betbonanza', name: 'BetBonanza', domain: 'betbonanza.com',
    baseUrl: 'https://www.betbonanza.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
  BookmakerConfig(
    id: 'betlion', name: 'BetLion', domain: 'betlion.com',
    baseUrl: 'https://www.betlion.com', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'supabet', name: 'Supabet', domain: 'supabet.com',
    baseUrl: 'https://www.supabet.com', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'elitebet', name: 'EliteBet NG', domain: 'elitebet.ng',
    baseUrl: 'https://www.elitebet.ng', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'supabets', name: 'Supabets NG', domain: 'ng.supabets.com',
    baseUrl: 'https://ng.supabets.com', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'betplus', name: 'BetPlus NG', domain: 'betplus.ng',
    baseUrl: 'https://www.betplus.ng', endpoints: _defaultEndpoints(),
    protected: true,
  ),
  BookmakerConfig(
    id: 'naijabet', name: 'NaijaBet', domain: 'naijabet.com',
    baseUrl: 'https://www.naijabet.com', endpoints: _defaultEndpoints(),
    protected: true, providesLeagueCategory: true,
  ),
];

BookmakerConfig? bookmakerById(String id) {
  for (final b in bookmakers) {
    if (b.id == id) return b;
  }
  return null;
}
