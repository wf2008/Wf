import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();
      final coordinator = ScanCoordinator();
      await coordinator.attemptAutomaticScan();
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await flnp.initialize(initSettings);

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
      theme: _buildTheme(),
      home: const _RootGate(),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF00897B);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: const Color(0xFF00897B),
        secondary: const Color(0xFF43A047),
        tertiary: const Color(0xFFF57F17),
        surface: Colors.white,
        background: const Color(0xFFF4F6F8),
        error: const Color(0xFFD32F2F),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F6F8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFF00897B),
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF00897B).withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00897B),
          side: const BorderSide(color: Color(0xFF00897B), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF00897B),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey.shade600),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE0F2F1),
        labelStyle: const TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF00897B),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF263238),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
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
          return const _SplashScreen();
        }
        if (snap.data == null) return const LoginScreen();
        return const _PostLoginGate();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00897B),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.trending_up, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Wfseek',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Arbitrage Scanner',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

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
    if (state == AppLifecycleState.resumed) _checkBattery();
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
    } catch (_) {
      ok = true;
    }
    if (!mounted) return;
    setState(() { _batteryOk = ok; _checking = false; });
  }

  Future<void> _openBatterySettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS');
      await intent.launch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    if (!_batteryOk) {
      return Scaffold(
        backgroundColor: const Color(0xFF00897B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.battery_alert, size: 72, color: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text('Background Access Required',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  'Wfseek needs to run in the background to continuously scan for arbitrage opportunities.',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00897B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _openBatterySettings,
                    child: const Text('Disable Battery Optimization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkBattery,
                  child: Text('Done — Re-check', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15)),
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
    return StreamBuilder<PlanStatus>(
      stream: AuthService().planStatusStream(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _SplashScreen();
        if (!snap.data!.isActive) return const ActivationScreen();
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
      if (!await cm.hasCookiesForDomain(bm.domain)) { allOk = false; break; }
    }
    if (!mounted) return;
    setState(() { _allVerified = allOk; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    if (!_allVerified) {
      return FirstTimeVerificationScreen(onAllVerified: () => setState(() => _allVerified = true));
    }
    return const HomeScreen();
  }
}
