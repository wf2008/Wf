import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../services/connection_manager.dart';
import '../services/scan_coordinator.dart';
import '../services/arb_detector.dart';
import 'activation_screen.dart';
import 'verification_screen.dart';
import 'settings_screen.dart';
import 'calculator_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _coord = ScanCoordinator();
  final _connMgr = ConnectionManager();
  final _db = FirebaseDatabase.instance;

  ConnectionMode? _mode;
  StreamSubscription<DatabaseEvent>? _wsSub;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  List<ArbOpportunity> _opps = [];
  int? _nextScanUtc;
  Duration _countdown = Duration.zero;
  bool _manualScanning = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nextScanUtc == null) return;
      final ms = _nextScanUtc! - DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _countdown =
            ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
      });
    });
    _db.ref('scan_state/next_scan_utc').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is int) setState(() => _nextScanUtc = v);
    });
  }

  Future<void> _bootstrap() async {
    final mode = await _connMgr.startConnection();
    setState(() => _mode = mode);
    if (mode == ConnectionMode.websocket) {
      _wsSub = _db.ref('opportunities').onValue.listen(_handleSnap);
    } else {
      _pollOnce();
      _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _pollOnce());
    }
  }

  Future<void> _pollOnce() async {
    final snap = await _db.ref('opportunities').get();
    _handleSnapValue(snap.value);
  }

  void _handleSnap(DatabaseEvent e) => _handleSnapValue(e.snapshot.value);

  void _handleSnapValue(Object? v) {
    final list = <ArbOpportunity>[];
    if (v is List) {
      for (final item in v) {
        if (item is Map) list.add(_fromMap(Map<String, dynamic>.from(item)));
      }
    } else if (v is Map) {
      for (final item in v.values) {
        if (item is Map) list.add(_fromMap(Map<String, dynamic>.from(item)));
      }
    }
    setState(() => _opps = list);
  }

  ArbOpportunity _fromMap(Map<String, dynamic> m) {
    final outcomesRaw = m['outcomes'] as Map? ?? {};
    final outcomes = <String, ArbOutcome>{};
    outcomesRaw.forEach((k, v) {
      if (v is Map) {
        outcomes[k.toString()] = ArbOutcome(
          label: k.toString(),
          bookmaker: (v['bookmaker'] ?? '').toString(),
          odds: (v['odds'] is num) ? (v['odds'] as num).toDouble() : 0.0,
        );
      }
    });
    final stakesRaw = m['stakes'] as Map? ?? {};
    final stakes = <String, double>{
      for (final e in stakesRaw.entries)
        e.key.toString(): (e.value is num) ? (e.value as num).toDouble() : 0.0,
    };
    return ArbOpportunity(
      id: (m['id'] ?? '').toString(),
      sport: (m['sport'] ?? '').toString(),
      market: (m['market'] ?? '').toString(),
      marketDetail: (m['market_detail'] ?? '').toString(),
      league: (m['league'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      homeTeam: (m['home_team'] ?? '').toString(),
      awayTeam: (m['away_team'] ?? '').toString(),
      profit: (m['profit'] is num) ? (m['profit'] as num).toDouble() : 0.0,
      outcomes: outcomes,
      stakes: stakes,
    );
  }

  Future<void> _manualScan() async {
    setState(() => _manualScanning = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Scanning...')));
    try {
      await _coord.manualScan();
      // Force a fetch regardless of mode
      await _pollOnce();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan complete – opportunities synced')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _manualScanning = false);
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _connMgr.manualDecrement();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanStatus>(
      stream: _auth.planStatusStream(),
      builder: (ctx, snap) {
        final plan = snap.data ?? PlanStatus(plan: 'free');
        final filtered = plan.plan == 'paid' && plan.isActive
            ? _opps
            : _opps.where((o) => o.profit <= 2.0).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Wfseek'),
            actions: [
              IconButton(
                icon: const Icon(Icons.verified_user),
                tooltip: 'Verification',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VerificationScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          body: Column(
            children: [
              _PlanBanner(plan: plan),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Next scan in ${_fmtDuration(_countdown)}'),
                    const Spacer(),
                    Text(
                      _mode == ConnectionMode.websocket
                          ? 'live'
                          : _mode == ConnectionMode.polling
                              ? 'polling'
                              : 'connecting…',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No opportunities yet.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final o = filtered[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${o.homeTeam} vs ${o.awayTeam}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text('+${o.profit}%',
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${o.sport} • ${o.marketDetail}${o.league.isNotEmpty ? " • ${o.league}" : ""}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  ...o.outcomes.entries.map(
                                    (e) => Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                              '${e.key}: ${e.value.odds.toStringAsFixed(2)}'),
                                        ),
                                        Text(e.value.bookmaker,
                                            style: const TextStyle(
                                                color: Colors.indigo)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.calculate),
                                      label: const Text('Calculate Stake'),
                                      onPressed: () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) =>
                                            CalculatorDialog(opportunity: o),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _manualScanning ? null : _manualScan,
            icon: _manualScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            label: const Text('Scan Now'),
          ),
        );
      },
    );
  }
}

class _PlanBanner extends StatelessWidget {
  final PlanStatus plan;
  const _PlanBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    final bool active = plan.isPaid;
    final bool expired = plan.plan != 'free' && !plan.isActive;

    String title;
    String? subtitle;
    Color color;
    Widget? trailing;

    if (active) {
      title = '${plan.label} – all opportunities unlocked';
      subtitle = plan.expiryText.isNotEmpty ? plan.expiryText : null;
      color = Colors.green.shade50;
    } else if (expired) {
      title = '${plan.label} – expired';
      subtitle = 'Renew to keep scanning';
      color = Colors.red.shade50;
      trailing = TextButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ActivationScreen())),
        child: const Text('Renew'),
      );
    } else {
      title = 'Free Tier – up to 2% profit only';
      subtitle = 'Upgrade to see all opportunities';
      color = Colors.amber.shade50;
      trailing = TextButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ActivationScreen())),
        child: const Text('Upgrade'),
      );
    }

    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
