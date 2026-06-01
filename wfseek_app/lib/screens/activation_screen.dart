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
  String? _msg;

  Future<void> _redeem() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final ok = await _auth.redeemCode(_code.text.trim());
      setState(() {
        _msg = ok ? 'Activated!' : 'Invalid or expired code';
      });
    } catch (e) {
      setState(() => _msg = e.toString());
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
          children: [
            const Text(
              'Enter your activation code (e.g. WFSEEK-ABCD-1234) to unlock the paid plan.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Activation Code',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _redeem,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Redeem'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!),
            ],
            const Spacer(),
            TextButton(
              onPressed: () async {
                await _auth.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
