import 'package:firebase_database/firebase_database.dart';

enum ConnectionMode { websocket, polling }

class ConnectionManager {
  static final ConnectionManager _i = ConnectionManager._();
  factory ConnectionManager() => _i;
  ConnectionManager._();

  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref('connected_clients/count');
  bool _registered = false;

  Future<ConnectionMode> startConnection() async {
    int? finalCount;
    var attempts = 0;
    while (attempts < 3) {
      attempts++;
      final txn = await _ref.runTransaction((current) {
        final n = current is int ? current : 0;
        return Transaction.success(n + 1);
      });
      if (txn.committed) {
        final v = txn.snapshot.value;
        if (v is int) finalCount = v;
        break;
      }
    }

    if (finalCount == null) {
      // Could not increment safely → default to polling.
      return ConnectionMode.polling;
    }

    if (!_registered) {
      _registered = true;
      _ref.onDisconnect().runTransaction((current) {
        final n = current is int ? current : 0;
        final next = n - 1;
        return Transaction.success(next < 0 ? 0 : next);
      });
    }

    return finalCount <= 100 ? ConnectionMode.websocket : ConnectionMode.polling;
  }

  Future<void> manualDecrement() async {
    await _ref.runTransaction((current) {
      final n = current is int ? current : 0;
      final next = n - 1;
      return Transaction.success(next < 0 ? 0 : next);
    });
  }
}
