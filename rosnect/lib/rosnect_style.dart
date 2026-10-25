import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const signalRed = Color(0xffd63c32);

ThemeData rosnectTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xfff1f0eb) : const Color(0xff191a19);
  final paper = dark ? const Color(0xff101110) : const Color(0xfff3f2ed);
  final panel = dark ? const Color(0xff1b1c1b) : const Color(0xfffdfcf8);
  final border = dark ? const Color(0xff343632) : const Color(0xffdeded6);
  final colors =
      ColorScheme.fromSeed(seedColor: signalRed, brightness: brightness)
          .copyWith(
    primary: ink,
    onPrimary: paper,
    primaryContainer: dark ? const Color(0xff292b27) : const Color(0xffe7e8df),
    onPrimaryContainer: ink,
    secondary: ink,
    secondaryContainer:
        dark ? const Color(0xff262822) : const Color(0xffe7e8df),
    onSecondaryContainer: ink,
    surface: paper,
    onSurface: ink,
    surfaceContainerLow: panel,
    surfaceContainerHighest:
        dark ? const Color(0xff292b27) : const Color(0xffe9e9e2),
    outline: dark ? const Color(0xff797c74) : const Color(0xff86897f),
    outlineVariant: border,
  );
  final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: paper,
      brightness: brightness);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w400,
          letterSpacing: -1.5,
          color: ink),
      titleLarge: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w400,
          letterSpacing: -.6,
          color: ink),
      titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          letterSpacing: -.2,
          color: ink),
      labelSmall: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          letterSpacing: .6,
          color: colors.onSurfaceVariant),
      labelMedium: TextStyle(
          fontFamily: 'monospace', fontSize: 11, letterSpacing: .6, color: ink),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false),
    cardTheme: CardTheme(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: border))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff242523) : const Color(0xfff1f1eb),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink)),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const StadiumBorder(),
            elevation: 0)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: const StadiumBorder(),
            side: BorderSide(color: border))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        height: 76,
        labelTextStyle: WidgetStateProperty.all(TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: .2,
            color: ink))),
    chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(), side: BorderSide(color: border)),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    expansionTileTheme:
        const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
  );
}

class AppearanceController extends ChangeNotifier {
  static const _channel = MethodChannel('rosnect/preferences');
  ThemeMode mode = ThemeMode.system;
  bool _disposed = false;
  bool _chosen = false;
  Future<void> load() async {
    try {
      final saved = await _channel.invokeMethod<String>('getTheme');
      if (_disposed || _chosen) return;
      mode = saved == 'dark'
          ? ThemeMode.dark
          : saved == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
      notifyListeners();
    } on Object {
      /* Use system appearance when platform preferences are unavailable. */
    }
  }

  void toggle(Brightness current) {
    _chosen = true;
    mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _channel
        .invokeMethod<void>(
            'setTheme', mode == ThemeMode.dark ? 'dark' : 'light')
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope(
      {required AppearanceController controller,
      required super.child,
      super.key})
      : super(notifier: controller);
  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppearanceScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    return IconButton(
        key: const ValueKey('theme-toggle'),
        tooltip: brightness == Brightness.dark
            ? 'Switch to light mode'
            : 'Switch to dark mode',
        onPressed: () => controller.toggle(brightness),
        icon: RosnectGlyph(brightness == Brightness.dark ? 'sun' : 'moon',
            size: 23));
  }
}

class RosnectLogo extends StatelessWidget {
  const RosnectLogo({this.size = 34, this.inverted, super.key});
  final double size;
  final bool? inverted;
  @override
  Widget build(BuildContext context) {
    final light = inverted ?? Theme.of(context).brightness == Brightness.light;
    return ClipOval(
        child: ColorFiltered(
            colorFilter: ColorFilter.matrix(light
                ? const [
                    -1,
                    0,
                    0,
                    0,
                    255,
                    0,
                    -1,
                    0,
                    0,
                    255,
                    0,
                    0,
                    -1,
                    0,
                    255,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]
                : const [
                    1,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0
                  ]),
            child: Image.asset('assets/dark_rosnect.png',
                height: size, width: size, fit: BoxFit.cover)));
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(
      {required this.index,
      required this.title,
      required this.subtitle,
      super.key});
  final String index, title, subtitle;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: signalRed, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('ROSNECT / $index',
              style: Theme.of(context).textTheme.labelSmall)
        ]),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label,
      {this.active = false, this.error = false, super.key});
  final String label;
  final bool active, error;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: error
                      ? signalRed
                      : active
                          ? const Color(0xff32956f)
                          : Theme.of(context).colorScheme.outline)),
          const SizedBox(width: 7),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      );
}

/// Original geometric marks: thin paths, small terminal dots and a sparse matrix.
class RosnectGlyph extends StatelessWidget {
  const RosnectGlyph(this.name, {this.size = 28, this.color, super.key});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
          painter: _GlyphPainter(
              name, color ?? Theme.of(context).colorScheme.onSurface)));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.name, this.color);
  final String name;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    void line(double x, double y, double xx, double yy) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), stroke);
    void dot(double x, double y, [double r = 1.7]) =>
        canvas.drawCircle(Offset(x, y), r, fill);
    switch (name) {
      case 'connection':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(5, 12, 22, 14), const Radius.circular(4)),
            stroke);
        line(11, 12, 11, 6);
        line(21, 12, 21, 6);
        dot(11, 5);
        dot(21, 5);
        dot(11, 19, 1);
        dot(16, 19, 1);
        dot(21, 19, 1);
      case 'sensors':
        for (var x = 0; x < 5; x++) {
          for (var y = 0; y < 5; y++) {
            if (x == 2 || y == 2 || (x + y) % 3 == 0) {
              dot(6 + x * 5, 6 + y * 5, (x == 2 && y == 2) ? 2 : 1.2);
            }
          }
        }
      case 'subscribe':
        line(9, 6, 5, 6);
        line(5, 6, 5, 26);
        line(5, 26, 9, 26);
        line(23, 6, 27, 6);
        line(27, 6, 27, 26);
        line(27, 26, 23, 26);
        dot(11, 16);
        dot(16, 16);
        dot(21, 16);
      case 'accelerometer':
        line(7, 25, 7, 8);
        line(7, 25, 24, 25);
        line(7, 25, 22, 10);
        dot(7, 6);
        dot(26, 25);
        dot(23, 8);
      case 'gyroscope':
        canvas.drawOval(const Rect.fromLTWH(4, 10, 24, 12), stroke);
        canvas.drawOval(const Rect.fromLTWH(10, 4, 12, 24), stroke);
        dot(16, 16, 2);
      case 'magnetometer':
        canvas.drawCircle(const Offset(16, 16), 12, stroke);
        final p = Path()
          ..moveTo(20, 8)
          ..lineTo(18, 18)
          ..lineTo(10, 23)
          ..lineTo(13, 13)
          ..close();
        canvas.drawPath(p, stroke);
        dot(16, 16, 1);
      case 'location':
        canvas.drawCircle(const Offset(16, 14), 8, stroke);
        dot(16, 14, 2);
        line(10, 21, 16, 28);
        line(22, 21, 16, 28);
      case 'light':
      case 'sun':
        canvas.drawCircle(const Offset(16, 16), 5, stroke);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          line(16 + 9 * math.cos(a), 16 + 9 * math.sin(a),
              16 + 12 * math.cos(a), 16 + 12 * math.sin(a));
        }
      case 'moon':
        final p = Path()
          ..moveTo(21, 4)
          ..cubicTo(1, 2, 0, 28, 18, 28)
          ..cubicTo(25, 28, 29, 23, 29, 19)
          ..cubicTo(14, 23, 12, 10, 21, 4);
        canvas.drawPath(p, stroke);
        dot(25, 8, 1);
      case 'barometer':
        canvas.drawArc(
            const Rect.fromLTWH(4, 7, 24, 24), math.pi, math.pi, false, stroke);
        line(5, 24, 27, 24);
        line(16, 21, 23, 12);
        dot(16, 21);
        dot(9, 13, 1);
        dot(16, 10, 1);
      case 'camera':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(4, 9, 24, 18), const Radius.circular(4)),
            stroke);
        canvas.drawCircle(const Offset(16, 18), 5, stroke);
        line(10, 9, 12, 5);
        line(12, 5, 20, 5);
        line(20, 5, 22, 9);
        dot(24, 13, 1);
      case 'microphone':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(12, 3, 8, 17), const Radius.circular(4)),
            stroke);
        canvas.drawArc(
            const Rect.fromLTWH(8, 8, 16, 17), 0, math.pi, false, stroke);
        line(16, 25, 16, 29);
        line(11, 29, 21, 29);
      case 'battery':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(3, 9, 24, 15), const Radius.circular(3)),
            stroke);
        line(30, 14, 30, 19);
        for (var i = 0; i < 3; i++) {
          line(8 + i * 6, 13, 8 + i * 6, 20);
        }
      case 'touch':
        canvas.drawCircle(const Offset(16, 12), 5, stroke);
        dot(16, 12, 1);
        final p = Path()
          ..moveTo(10, 27)
          ..lineTo(8, 21)
          ..quadraticBezierTo(8, 17, 12, 20)
          ..lineTo(13, 12)
          ..quadraticBezierTo(16, 8, 18, 13)
          ..lineTo(19, 19)
          ..quadraticBezierTo(28, 17, 25, 27);
        canvas.drawPath(p, stroke);
      default:
        dot(7, 16);
        dot(16, 16);
        dot(25, 16);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.name != name || old.color != color;
}
