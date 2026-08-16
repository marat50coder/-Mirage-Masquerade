import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palette.dart';
import 'screens/boot_screen.dart';
import 'veil/config/veil_config.dart';
import 'veil/infra/herald_hub.dart';
import 'veil/infra/ledger_exchange.dart';
import 'veil/infra/masque_vault.dart';
import 'veil/infra/mummer_agent.dart';
import 'veil/infra/signal_scout.dart';
import 'veil/infra/trace_courier.dart';
import 'veil/veil_director.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  final vault = MasqueVault();
  final agent = MummerAgent();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
  ]);

  // Firebase / App Check only matter when the veil gate can open. Attribution
  // and the config POST still run without them; only push needs Firebase.
  var pushServicesReady = false;
  if (VeilConfig.veilCredentialsReady) {
    try {
      await Firebase.initializeApp();
      pushServicesReady = true;
    } catch (_) {}
    if (pushServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (_) {
        // App Check must never block FCM / routing.
      }
    }
  }

  final scout = SignalScout();
  final herald = HeraldHub(vault, enabled: pushServicesReady);
  final courier = TraceCourier(agent);
  final ledger = LedgerExchange(agent, vault);
  final director = VeilDirector(
    vault: vault,
    scout: scout,
    courier: courier,
    ledger: ledger,
    herald: herald,
    agent: agent,
    runtimeEnabled: true,
  );

  runApp(MirageMasqueradeApp(director: director));
}

class MirageMasqueradeApp extends StatelessWidget {
  const MirageMasqueradeApp({super.key, this.director});

  final VeilDirector? director;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirage Masquerade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MM.night,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MM.amethyst,
          brightness: Brightness.dark,
          surface: MM.deep,
        ),
        fontFamily: null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      builder: (context, child) => MediaQuery.withNoTextScaling(
        child: child ?? const SizedBox.shrink(),
      ),
      home: BootScreen(director: director),
    );
  }
}
