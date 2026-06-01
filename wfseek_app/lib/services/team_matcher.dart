import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class MatchedGroup {
  final String sport;
  final String market;
  final String marketDetail;
  final String league;
  final String category;
  final String homeTeam;
  final String awayTeam;

  /// bookmakerId -> raw event map (containing outcomes)
  final Map<String, Map<String, dynamic>> entriesByBookmaker;

  MatchedGroup({
    required this.sport,
    required this.market,
    required this.marketDetail,
    required this.league,
    required this.category,
    required this.homeTeam,
    required this.awayTeam,
    required this.entriesByBookmaker,
  });
}

class TeamMatcher {
  static final TeamMatcher _i = TeamMatcher._();
  factory TeamMatcher() => _i;
  TeamMatcher._();

  Interpreter? _interpreter;
  bool _failed = false;

  static const _stopwords = {
    'fc', 'ac', 'cf', 'sc', 'united', 'city', 'town',
    'athletic', 'wanderers', 'rovers',
  };

  static const Map<String, String> _leagueSynonyms = {
    'epl': 'premier league',
    'english premier league': 'premier league',
    'laliga': 'la liga',
    'la liga santander': 'la liga',
    'ucl': 'uefa champions league',
    'champions league': 'uefa champions league',
    'uel': 'uefa europa league',
    'europa league': 'uefa europa league',
    'serie a tim': 'serie a',
    'bundesliga 1': 'bundesliga',
    'ligue 1 uber eats': 'ligue 1',
    'npfl': 'nigeria premier football league',
    'nigeria professional football league': 'nigeria premier football league',
  };

  static const Map<String, String> _nigerianTeamSynonyms = {
    'enyimba': 'enyimba international',
    '3sc': 'shooting stars',
    'shooting stars sc': 'shooting stars',
    'rangers': 'enugu rangers',
    'mfm': 'mfm fc',
    'heartland': 'heartland fc',
    'kano pillars': 'kano pillars fc',
    'wikki': 'wikki tourists',
    'lobi': 'lobi stars',
    'sunshine': 'sunshine stars',
    'abia': 'abia warriors',
    'plateau': 'plateau united',
    'nasarawa': 'nasarawa united',
    'kwara': 'kwara united',
    'remo': 'remo stars',
    'doma': 'doma united',
    'bayelsa': 'bayelsa united',
    'akwa': 'akwa united',
    'rivers': 'rivers united',
    'gombe': 'gombe united',
    'el-kanemi': 'el-kanemi warriors',
    'el kanemi': 'el-kanemi warriors',
  };

  Future<void> _ensureLoaded() async {
    if (_interpreter != null || _failed) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
    } catch (_) {
      _failed = true;
    }
  }

  String _removeDiacritics(String s) {
    const from = 'àáâãäåèéêëìíîïòóôõöùúûüñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÑÇ';
    const to = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      sb.write(i >= 0 ? to[i] : ch);
    }
    return sb.toString();
  }

  String normalizeTeam(String name) {
    var s = _removeDiacritics(name.toLowerCase().trim());
    s = _nigerianTeamSynonyms[s] ?? s;
    final tokens = s
        .split(RegExp(r'[\s\.\-_/]+'))
        .where((t) => t.isNotEmpty && !_stopwords.contains(t))
        .toList()
      ..sort();
    return tokens.join(' ');
  }

  String normalizeLeague(String l) {
    final low = _removeDiacritics(l.toLowerCase().trim());
    return _leagueSynonyms[low] ?? low;
  }

  /// Deterministic 64-dim hashing embedding, used as fallback (and as a
  /// stable shape so the rest of the pipeline does not depend on the tflite
  /// model being shipped).
  List<double> _hashEmbedding(String text) {
    const dim = 64;
    final v = List<double>.filled(dim, 0.0);
    for (final tok in text.split(' ')) {
      if (tok.isEmpty) continue;
      final h = tok.hashCode;
      final idx = (h & 0x7fffffff) % dim;
      final sign = ((h >> 31) & 1) == 0 ? 1.0 : -1.0;
      v[idx] += sign;
    }
    // L2 normalize
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  Future<List<double>> getEmbedding(String text) async {
    final norm = normalizeTeam(text);
    await _ensureLoaded();
    if (_interpreter == null) {
      return _hashEmbedding(norm);
    }
    try {
      // The exported sentence-transformers model has a tokenizer attached only
      // through the saved-model signature. We feed a simple int sequence based
      // on char codes as a best-effort fallback. In production, replace with
      // a proper tokenizer.
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outShape = _interpreter!.getOutputTensor(0).shape;
      final seqLen = inputShape.length >= 2 ? inputShape[1] : 32;
      final ids = List<int>.filled(seqLen, 0);
      for (var i = 0; i < norm.length && i < seqLen; i++) {
        ids[i] = norm.codeUnitAt(i) & 0x7fff;
      }
      final input = [ids];
      final output = List.generate(
        outShape[0],
        (_) => List<double>.filled(outShape.last, 0.0),
      );
      _interpreter!.run(input, output);
      return output[0];
    } catch (_) {
      return _hashEmbedding(norm);
    }
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  /// Match team names across bookmakers. Groups are limited to events that
  /// share (sport, market, marketDetail) and ideally (league, category).
  ///
  /// [providesLeagueCategoryByBm] tells, per bookmaker id, whether its events
  /// carry reliable league/category metadata.
  Future<List<MatchedGroup>> matchTeams(
    Map<String, List<Map<String, dynamic>>> oddsByBookmaker,
    String sport,
    String market, {
    required Map<String, bool> providesLeagueCategoryByBm,
  }) async {
    // Step 1: bucket entries by (league, category, marketDetail) when reliable.
    final Map<String, List<MapEntry<String, Map<String, dynamic>>>> buckets = {};
    oddsByBookmaker.forEach((bmId, events) {
      final reliable = providesLeagueCategoryByBm[bmId] ?? false;
      for (final e in events) {
        final detail = (e['market_detail'] ?? market).toString();
        final league = (e['league'] ?? '').toString();
        final category = (e['category'] ?? '').toString();
        final useMeta = reliable && league.isNotEmpty;
        final key = useMeta
            ? 'meta|${normalizeLeague(league)}|$category|$detail'
            : 'unknown|$detail';
        buckets.putIfAbsent(key, () => []).add(MapEntry(bmId, e));
      }
    });

    final groups = <MatchedGroup>[];

    for (final entry in buckets.entries) {
      final list = entry.value;
      // Cache embeddings
      final homeEmb = <int, List<double>>{};
      final awayEmb = <int, List<double>>{};
      for (var i = 0; i < list.length; i++) {
        homeEmb[i] = await getEmbedding(list[i].value['home_team']?.toString() ?? '');
        awayEmb[i] = await getEmbedding(list[i].value['away_team']?.toString() ?? '');
      }
      final used = List<bool>.filled(list.length, false);
      for (var i = 0; i < list.length; i++) {
        if (used[i]) continue;
        used[i] = true;
        final cluster = <String, Map<String, dynamic>>{
          list[i].key: list[i].value,
        };
        for (var j = i + 1; j < list.length; j++) {
          if (used[j]) continue;
          if (list[j].key == list[i].key) continue; // same bookmaker, skip
          final sHome = cosineSimilarity(homeEmb[i]!, homeEmb[j]!);
          final sAway = cosineSimilarity(awayEmb[i]!, awayEmb[j]!);
          if (sHome > 0.85 && sAway > 0.85) {
            used[j] = true;
            cluster[list[j].key] = list[j].value;
          }
        }
        if (cluster.length < 2) continue;
        final e0 = list[i].value;
        groups.add(MatchedGroup(
          sport: sport,
          market: market,
          marketDetail: (e0['market_detail'] ?? market).toString(),
          league: (e0['league'] ?? '').toString(),
          category: (e0['category'] ?? '').toString(),
          homeTeam: (e0['home_team'] ?? '').toString(),
          awayTeam: (e0['away_team'] ?? '').toString(),
          entriesByBookmaker: cluster,
        ));
      }
    }
    return groups;
  }
}
