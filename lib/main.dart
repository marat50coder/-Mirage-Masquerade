import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'studio/palette.dart';
import 'foyer/boot_screen.dart';
import 'proscenium/config/house_brief.dart';
import 'proscenium/infra/callboy.dart';
import 'proscenium/infra/box_office.dart';
import 'proscenium/infra/wardrobe.dart';
import 'proscenium/infra/footlight_agent.dart';
import 'proscenium/infra/aisle_watch.dart';
import 'proscenium/infra/playbill_scout.dart';
import 'proscenium/house_usher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  final vault = Wardrobe();
  final agent = FootlightAgent();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
  ]);

  // Firebase / App Check only matter when the house gate can open. Attribution
  // and the config POST still run without them; only push needs Firebase.
  var pushServicesReady = false;
  if (HouseBrief.houseCredentialsReady) {
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

  final scout = AisleWatch();
  final herald = Callboy(vault, enabled: pushServicesReady);
  final courier = PlaybillScout(agent);
  final ledger = BoxOffice(agent, vault);
  final director = HouseUsher(
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

  final HouseUsher? director;

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
