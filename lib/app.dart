import 'dart:async';

import 'package:flutter/material.dart';

import 'game/controller.dart';
import 'game/palette.dart';
import 'screens/home_screen.dart';

class CrossmateApp extends StatefulWidget {
  const CrossmateApp({super.key});

  @override
  State<CrossmateApp> createState() => _CrossmateAppState();
}

class _CrossmateAppState extends State<CrossmateApp> {
  late final CrossmateController controller;

  @override
  void initState() {
    super.initState();
    controller = CrossmateController();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Crossmate',
          debugShowCheckedModeBanner: false,
          theme: buildCrossmateTheme(controller.theme),
          home: HomeScreen(controller: controller),
        );
      },
    );
  }
}
