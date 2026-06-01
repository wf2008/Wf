import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/scan_coordinator.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/activation_screen.dart';
import 'screens/first_time_verification_screen.dart';
import 'services/auth_service.dart';
import 'services/cookie_manager.dart';
import 'scrapers/config.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();
      final coordinator = ScanCoordinator();
      await coordinator.attemptAutomaticScan();
    } catch (e) {
      // Swallow errors so the periodic task does not crash.
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Local notifications init
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await flnp.initialize(initSettings);

  // Workmanager init
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'scanTaskId',
    'scanTask',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  runApp(const WfseekApp());
}

class WfseekApp extends StatelessWidget {
  const WfseekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wfseek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          return const LoginScreen();
        }
        return const _PostLoginGate();
      },
    );
  }
}

/// After login, enforces:
///  1) Battery optimization exemption (Android) / Background refresh (iOS)
///  2) Plan activation check
///  3) Mandatory cookie verification for protected bookmakers
class _PostLoginGate extends StatefulWidget {
  const _PostLoginGate();
  @override
  State<_PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<_PostLoginGate> with WidgetsBindingObserver {
  static const _platform = MethodChannel('wfseek/system');
  bool _checking = true;
  bool _batteryOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBattery();
    }
  }

  Future<void> _checkBattery() async {
    setState(() => _checking = true);
    bool ok = true;
    try {
      if (Platform.isAndroid) {
        final res = await _platform.invokeMethod<bool>('isIgnoringBatteryOptimizations');
        ok = res ?? false;
      } else if (Platform.isIOS) {
        final res = await _platform.invokeMethod<bool>('isBackgroundRefreshEnabled');
        ok = res ?? true;
      }
    } on PlatformException {
      // If platform channel not yet wired in, treat as OK so dev builds still work.
      ok = true;
    } on MissingPluginException {
      ok = true;
    }
    if (!mounted) return;
    setState(() {
      _batteryOk = ok;
      _checking = false;
    });
  }

  Future<void> _openBatterySettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_batteryOk) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.battery_alert, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Battery optimization required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Wfseek needs to run in the background to scan opportunities. Please disable battery optimization.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _openBatterySettings,
                  child: const Text('Open Settings'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _checkBattery,
                  child: const Text('I have disabled it – Re-check'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const _PlanGate();
  }
}

class _PlanGate extends StatelessWidget {
  const _PlanGate();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<PlanStatus>(
      stream: auth.planStatusStream(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final plan = snap.data!;
        if (!plan.isActive) {
          return const ActivationScreen();
        }
        return const _CookieGate();
      },
    );
  }
}

class _CookieGate extends StatefulWidget {
  const _CookieGate();
  @override
  State<_CookieGate> createState() => _CookieGateState();
}

class _CookieGateState extends State<_CookieGate> {
  bool _loading = true;
  bool _allVerified = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final cm = CookieManager();
    bool allOk = true;
    for (final bm in bookmakers.where((b) => b.protected)) {
      final hasCookies = await cm.hasCookiesForDomain(bm.domain);
      if (!hasCookies) {
        allOk = false;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _allVerified = allOk;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allVerified) {
      return FirstTimeVerificationScreen(onAllVerified: () {
        setState(() => _allVerified = true);
      });
    }
    return const HomeScreen();
  }
}
