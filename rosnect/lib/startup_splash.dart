import 'package:flutter/material.dart';
import 'rosnect_style.dart';

/// A single, logo-only opening screen; returning to the app does not replay it.
class StartupSplash extends StatefulWidget {
  const StartupSplash({required this.child, super.key});
  final Widget child;
  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _opening;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _opening = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _finished = true);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _finished
      ? widget.child
      : const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: RosnectLogo(size: 144, inverted: false)),
        );
}
