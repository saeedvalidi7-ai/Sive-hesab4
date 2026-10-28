import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text, Card;
import 'util.dart';

const themeNames = {
  'royal': 'کرم و سبز درباری',
  'dark': 'تیره',
  'pastel': 'پاستیلی',
  'ocean': 'اقیانوسی',
  'rose': 'گل‌بهی',
  'glass': 'آینه‌ای شیشه‌ای',
  '3d': 'سه‌بعدی',
};

ThemeData buildTheme(String k) {
  Color seed, bg, bar;
  var br = Brightness.light;
  switch (k) {
    case 'dark':
      seed = const Color(0xFF2E8B57); bg = const Color(0xFF101614); bar = const Color(0xFF16221D); br = Brightness.dark; break;
    case 'pastel':
      seed = const Color(0xFFB39DDB); bg = const Color(0xFFFAF7FF); bar = const Color(0xFFEDE7F6); break;
    case 'ocean':
      seed = const Color(0xFF0288D1); bg = const Color(0xFFF0F9FF); bar = const Color(0xFFD6EEFA); break;
    case 'glass':
      seed = const Color(0xFF00838F); bg = Colors.transparent; bar = Colors.transparent; break;
    case '3d':
      seed = const Color(0xFF5E35B1); bg = Colors.transparent; bar = Colors.transparent; break;
    case 'rose':
      seed = const Color(0xFFD81B60); bg = const Color(0xFFFFF5F8); bar = const Color(0xFFFCE4EC); break;
    default:
      seed = const Color(0xFF1B5E3F); bg = const Color(0xFFFBF6E9); bar = const Color(0xFFEFE3C2);
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: br),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(backgroundColor: bar, centerTitle: true),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: br == Brightness.dark ? const Color(0xFF1E2B25) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
  );
}

class SivaLogo extends StatelessWidget {
  final double size;
  const SivaLogo({super.key, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E8B57), Color(0xFF0B3D2A)]),
        border: Border.all(color: const Color(0xFFD4AF37), width: size * 0.05),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: size * 0.15, offset: Offset(0, size * 0.06))],
      ),
      child: Center(
        child: Text('س', style: TextStyle(fontSize: size * 0.6, height: 1, fontWeight: FontWeight.bold, color: const Color(0xFFF5E6B3))),
      ),
    );
  }
}

class Splash extends StatefulWidget {
  final Widget next;
  const Splash({super.key, required this.next});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
              pageBuilder: (_, __, ___) => widget.next,
              transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF6E9), Color(0xFFCFE8D5)])),
        child: Center(
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(c.value);
              final f = Curves.easeIn.transform(((c.value - 0.5) / 0.5).clamp(0.0, 1.0));
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY((1 - t) * math.pi * 1.5),
                  child: Transform.scale(scale: 0.4 + 0.6 * t, child: const SivaLogo(size: 150)),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: f,
                  child: const Column(children: [
                    Text('سیوا حساب', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFF0B3D2A))),
                    SizedBox(height: 6),
                    Text('حسابداری و فاکتور هوشمند ویزیتورها', style: TextStyle(fontSize: 16, color: Color(0xFF6B5A1E))),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
