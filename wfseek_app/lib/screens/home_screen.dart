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
      if (mounted) setState(() => _countdown = ms > 0 ? Duration(milliseconds: ms) : Duration.zero);
    });
    _db.ref('scan_state/next_scan_utc').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is int && mounted) setState(() => _nextScanUtc = v);
    });
  }

  Future<void> _bootstrap() async {
    final mode = await _connMgr.startConnection();
    if (!mounted) return;
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
      for (final item in v) { if (item is Map) list.add(_fromMap(Map<String, dynamic>.from(item))); }
    } else if (v is Map) {
      for (final item in v.values) { if (item is Map) list.add(_fromMap(Map<String, dynamic>.from(item))); }
    }
    if (mounted) setState(() => _opps = list);
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
    if (!mounted) return;
    setState(() => _manualScanning = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Scanning all bookmakers…'),
      ])),
    );
    try {
      await _coord.manualScan();
      await _pollOnce();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Scan complete — opportunities synced'),
            ]),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: const Color(0xFFD32F2F)),
        );
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

  String _sportEmoji(String sport) {
    const map = {
      'soccer': '⚽', 'basketball': '🏀', 'tennis': '🎾',
      'volleyball': '🏐', 'hockey': '🏒', 'american_football': '🏈',
    };
    return map[sport] ?? '🏆';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanStatus>(
      stream: _auth.planStatusStream(),
      builder: (ctx, snap) {
        final plan = snap.data ?? PlanStatus(plan: 'free');
        final filtered = plan.isPaid
            ? _opps
            : _opps.where((o) => o.profit <= 2.0).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Wfseek'),
            actions: [
              IconButton(
                icon: const Icon(Icons.verified_user_outlined),
                tooltip: 'Verification',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Plan banner ──────────────────────────────────────
              _PlanBanner(plan: plan),

              // ── Status bar ───────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _StatusDot(mode: _mode),
                    const SizedBox(width: 8),
                    Text(
                      _mode == ConnectionMode.websocket ? 'Live' : _mode == ConnectionMode.polling ? 'Polling' : 'Connecting…',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF00897B)),
                    const SizedBox(width: 4),
                    Text(
                      'Next scan in ${_fmtDuration(_countdown)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF00897B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Opportunities list ────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(isPaid: plan.isPaid)
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 100),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _ArbCard(
                          opp: filtered[i],
                          sportEmoji: _sportEmoji(filtered[i].sport),
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _manualScanning ? null : _manualScan,
            backgroundColor: _manualScanning ? Colors.grey.shade400 : const Color(0xFF00897B),
            icon: _manualScanning
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.radar, color: Colors.white),
            label: Text(_manualScanning ? 'Scanning…' : 'Scan Now',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

// ── Plan banner ──────────────────────────────────────────────────────────────

class _PlanBanner extends StatelessWidget {
  final PlanStatus plan;
  const _PlanBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    final bool active = plan.isPaid;
    final bool expired = plan.plan != 'free' && !plan.isActive;

    Color bg;
    Color textColor;
    IconData icon;
    String title;
    String? sub;
    Widget? action;

    if (active) {
      bg = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
      icon = Icons.verified;
      title = '${plan.label} — All opportunities unlocked';
      sub = plan.expiryText.isNotEmpty ? plan.expiryText : null;
    } else if (expired) {
      bg = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFD32F2F);
      icon = Icons.warning_amber_rounded;
      title = '${plan.label} — Expired';
      sub = 'Renew your plan to keep scanning';
      action = TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivationScreen())),
        child: const Text('Renew', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w700)),
      );
    } else {
      bg = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFF57F17);
      icon = Icons.lock_outline;
      title = 'Free Tier — Up to 2% profit shown';
      sub = 'Upgrade to see all opportunities';
      action = TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivationScreen())),
        child: const Text('Upgrade', style: TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.w700)),
      );
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                if (sub != null) Text(sub, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

// ── Status dot ───────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final ConnectionMode? mode;
  const _StatusDot({this.mode});
  @override
  Widget build(BuildContext context) {
    final color = mode == ConnectionMode.websocket
        ? const Color(0xFF43A047)
        : mode == ConnectionMode.polling
            ? const Color(0xFFFFA000)
            : Colors.grey;
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)]),
    );
  }
}

// ── Arb card ─────────────────────────────────────────────────────────────────

class _ArbCard extends StatelessWidget {
  final ArbOpportunity opp;
  final String sportEmoji;
  const _ArbCard({required this.opp, required this.sportEmoji});

  Color _profitColor(double p) {
    if (p >= 3) return const Color(0xFF1B5E20);
    if (p >= 1.5) return const Color(0xFF2E7D32);
    return const Color(0xFF43A047);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sport badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(sportEmoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                // Teams
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${opp.homeTeam} vs ${opp.awayTeam}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          opp.marketDetail,
                          if (opp.league.isNotEmpty) opp.league,
                        ].join(' • '),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Profit badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _profitColor(opp.profit),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${opp.profit.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Outcomes ─────────────────────────────────────
            ...opp.outcomes.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.value.odds.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF00897B)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.value.bookmaker,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF00695C), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )),

            // ── Calculate button ─────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Calculate Stake'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00897B),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => CalculatorDialog(opportunity: opp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isPaid;
  const _EmptyState({required this.isPaid});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.radar, size: 44, color: Color(0xFF00897B)),
            ),
            const SizedBox(height: 20),
            const Text('No opportunities yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF37474F))),
            const SizedBox(height: 8),
            Text(
              isPaid
                  ? 'Tap "Scan Now" to start scanning all 30 bookmakers'
                  : 'Upgrade to Pro to see all opportunities above 2%',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
