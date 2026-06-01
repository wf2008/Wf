import 'package:flutter/material.dart';
import '../services/arb_detector.dart';

class CalculatorDialog extends StatefulWidget {
  final ArbOpportunity opportunity;
  const CalculatorDialog({super.key, required this.opportunity});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  final _total = TextEditingController(text: '1000');
  final _detector = ArbDetector();
  Map<String, double> _stakes = {};

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  void _recalc() {
    final total = double.tryParse(_total.text) ?? 0.0;
    final odds = {
      for (final e in widget.opportunity.outcomes.entries) e.key: e.value.odds,
    };
    setState(() {
      _stakes = _detector.calculateStakes(odds, total);
    });
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.opportunity;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${op.homeTeam} vs ${op.awayTeam}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text('${op.marketDetail} • profit ${op.profit}%'),
          const SizedBox(height: 16),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total stake (NGN)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _recalc(),
          ),
          const SizedBox(height: 16),
          ..._stakes.entries.map((e) {
            final outcome = op.outcomes[e.key];
            return ListTile(
              dense: true,
              title: Text('${e.key} @ ${outcome?.odds.toStringAsFixed(2)}'),
              subtitle: Text('Bookmaker: ${outcome?.bookmaker}'),
              trailing: Text('₦${e.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }),
        ],
      ),
    );
  }
}
