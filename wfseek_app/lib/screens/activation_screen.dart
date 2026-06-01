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
    if (input.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
      _activatedPlan = null;
    });
    try {
      final ok = await _auth.redeemCode(input);
      if (ok) {
        final stream = _auth.planStatusStream();
        final status = await stream.first;
        setState(() => _activatedPlan = status);
      } else {
        setState(() => _errorMsg = 'Invalid or already-used code. Check and try again.');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activate Plan')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Plan info cards ──────────────────────────────
            const Text(
              'Choose a plan — pay the admin and get your code:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              icon: '📅',
              title: 'Weekly Plan',
              subtitle: '7 days of full access',
              color: Colors.blue.shade50,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              icon: '📆',
              title: 'Monthly Plan',
              subtitle: '30 days of full access',
              color: Colors.green.shade50,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              icon: '♾',
              title: 'Family Plan',
              subtitle: 'Never expires — for family only',
              color: Colors.purple.shade50,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── Success state ────────────────────────────────
            if (_activatedPlan != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    Text(
                      'Activated!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activatedPlan!.label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activatedPlan!.expiryText,
                      style: TextStyle(color: Colors.green.shade600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go to Dashboard'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── Code entry ───────────────────────────────
              const Text(
                'Enter your activation code:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'e.g. WFSEEK-ABCD-1234',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loading ? null : _redeem,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle),
                label: const Text('Activate'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ],

            const Spacer(),
            TextButton(
              onPressed: () async => _auth.signOut(),
              child: const Text('Sign out'),
            ),
          ],
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
  const _PlanCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
