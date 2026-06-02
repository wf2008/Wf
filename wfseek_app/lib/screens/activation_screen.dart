import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _code = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _errorMsg;
  PlanStatus? _activatedPlan;

  Future<void> _redeem() async {
    final input = _code.text.trim().toUpperCase();
    if (input.isEmpty) {
      setState(() => _errorMsg = 'Please enter your activation code.');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; _activatedPlan = null; });
    try {
      final ok = await _auth.redeemCode(input);
      if (ok) {
        final status = await _auth.planStatusStream().first;
        if (mounted) setState(() => _activatedPlan = status);
      } else {
        if (mounted) setState(() => _errorMsg = 'Invalid or already-used code. Please check and try again.');
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('permission-denied')) {
        msg = 'Permission error. Please check your Firebase rules allow activation_codes write access.';
      }
      if (mounted) setState(() => _errorMsg = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 36),
                    const SizedBox(height: 12),
                    const Text('Activate Plan',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Choose a plan, pay the admin, get your code',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Success state ──────────────────────────────
                    if (_activatedPlan != null) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 44),
                            ),
                            const SizedBox(height: 16),
                            const Text('Activated!',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_activatedPlan!.label,
                                  style: const TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                            if (_activatedPlan!.expiryText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(_activatedPlan!.expiryText,
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.dashboard_outlined),
                                label: const Text('Go to Dashboard'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // ── Plan cards ─────────────────────────────────
                      _PlanCard(icon: '📅', title: 'Weekly Plan', subtitle: '7 days of full access',
                          color: const Color(0xFFE3F2FD), borderColor: const Color(0xFF90CAF9)),
                      const SizedBox(height: 10),
                      _PlanCard(icon: '📆', title: 'Monthly Plan', subtitle: '30 days of full access',
                          color: const Color(0xFFE8F5E9), borderColor: const Color(0xFF81C784)),
                      const SizedBox(height: 10),
                      _PlanCard(icon: '♾', title: 'Family Plan', subtitle: 'Never expires — for family only',
                          color: const Color(0xFFF3E5F5), borderColor: const Color(0xFFCE93D8)),
                      const SizedBox(height: 28),

                      // ── Code entry ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Enter Activation Code',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 4),
                            Text('You receive this code after payment',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _code,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w600, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'WFSEEK-ABCD-1234',
                                hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 1, fontWeight: FontWeight.normal),
                                prefixIcon: const Icon(Icons.vpn_key_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: _loading
                                    ? const SizedBox(width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(_loading ? 'Activating…' : 'Activate'),
                                onPressed: _loading ? null : _redeem,
                              ),
                            ),
                            if (_errorMsg != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFEF9A9A)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_errorMsg!,
                                        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13))),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Sign out'),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
                        onPressed: () async => _auth.signOut(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color borderColor;
  const _PlanCard({required this.icon, required this.title, required this.subtitle,
      required this.color, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E))),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
