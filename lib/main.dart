import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'foyer/boot_screen.dart';
import 'studio/attribution.dart';
import 'studio/palette.dart';
import 'studio/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  unawaited(Attribution.instance.start());
  unawaited(Reminders.instance.prepare());
  runApp(const MirageMasqueradeApp());
}

class MirageMasqueradeApp extends StatelessWidget {
  const MirageMasqueradeApp({super.key});

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
      home: const BootScreen(),
    );
  }
}
