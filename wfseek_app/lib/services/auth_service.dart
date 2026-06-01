import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PlanStatus {
  final String plan; // 'free' | 'weekly' | 'monthly' | 'family'
  final int? expiry; // ms since epoch; 0 = never expires

  PlanStatus({required this.plan, this.expiry});

  bool get isActive {
    if (plan == 'free') return false;
    if (expiry == 0) return true; // family — never expires
    if (expiry != null) {
      return DateTime.now().millisecondsSinceEpoch < expiry!;
    }
    return false;
  }

  bool get isPaid => plan != 'free' && isActive;

  String get label {
    switch (plan) {
      case 'weekly':
        return 'Weekly Plan';
      case 'monthly':
        return 'Monthly Plan';
      case 'family':
        return 'Family Plan ♾';
      case 'paid':
        return 'Pro Plan';
      case 'free':
      default:
        return 'Free Tier';
    }
  }

  /// Human-readable expiry string shown in the banner
  String get expiryText {
    if (plan == 'free') return '';
    if (expiry == 0) return 'Never expires';
    if (expiry == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(expiry!);
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays >= 2) return 'Expires in ${diff.inDays} days';
    if (diff.inDays == 1) return 'Expires tomorrow';
    return 'Expires today';
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;

  Future<User?> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.child('users/$uid').set({
      'plan': 'free',
      'activation_expiry': null,
    });
    return cred.user;
  }

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final snap = await _db.child('users/$uid').get();
    if (!snap.exists) {
      await _db.child('users/$uid').set({
        'plan': 'free',
        'activation_expiry': null,
      });
    }
    return cred.user;
  }

  Future<void> signOut() => _auth.signOut();

  /// Redeem an activation code. Returns true on success.
  Future<bool> redeemCode(String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final codeRef = _db.child('activation_codes/$code');

    final txn = await codeRef.runTransaction((current) {
      if (current == null) return Transaction.abort();
      final map = Map<String, dynamic>.from(current as Map);
      if (map['used'] == true) return Transaction.abort();
      final expires = map['expires'];
      // expires == 0 means never expires — always valid
      if (expires is int && expires != 0 &&
          expires < DateTime.now().millisecondsSinceEpoch) {
        return Transaction.abort();
      }
      map['used'] = true;
      map['used_by'] = uid;
      return Transaction.success(map);
    });

    if (!txn.committed) return false;
    final data = Map<String, dynamic>.from(txn.snapshot.value as Map);
    await _db.child('users/$uid').update({
      'plan': data['plan'] ?? 'paid',
      'activation_expiry': data['expires'] ?? 0,
    });
    return true;
  }

  Stream<PlanStatus> planStatusStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(PlanStatus(plan: 'free'));
    }
    return _db.child('users/$uid').onValue.map((event) {
      final v = event.snapshot.value;
      if (v == null) return PlanStatus(plan: 'free');
      final m = Map<String, dynamic>.from(v as Map);
      final expiry = m['activation_expiry'];
      return PlanStatus(
        plan: (m['plan'] ?? 'free').toString(),
        expiry: expiry is int ? expiry : null,
      );
    });
  }
}
