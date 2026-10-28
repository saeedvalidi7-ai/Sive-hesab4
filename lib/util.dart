import 'dart:io';
import 'package:flutter/material.dart' as m;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String jalali(DateTime dt) {
  final gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy = dt.year, gm = dt.month, gd = dt.day;
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) + gd + gdm[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return '$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}';
}

Future<String?> pickImagePath() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
  if (x == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final f = await File(x.path)
      .copy(p.join(dir.path, 'img_${DateTime.now().millisecondsSinceEpoch}.png'));
  return f.path;
}

String fa(String s) {
  const f = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final c in s.runes) {
    final ch = String.fromCharCode(c);
    final i = '0123456789'.indexOf(ch);
    b.write(i >= 0 ? f[i] : ch);
  }
  return b.toString();
}

/// Text که همهٔ اعداد را فارسی نمایش می‌دهد.
class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final m.TextAlign? textAlign;
  final int? maxLines;
  final m.TextOverflow? overflow;
  const Text(this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow});
  @override
  m.Widget build(m.BuildContext context) =>
      m.Text(fa(data), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}

final m.ValueNotifier<String> themeNotifier = m.ValueNotifier<String>('royal');

/// Card که ظاهرش با تم (معمولی، آینه‌ای، سه‌بعدی) تغییر می‌کند.
class Card extends m.StatelessWidget {
  final m.Widget child;
  final m.EdgeInsetsGeometry? margin;
  const Card({super.key, required this.child, this.margin});
  @override
  m.Widget build(m.BuildContext context) {
    final k = themeNotifier.value;
    final cs = m.Theme.of(context).colorScheme;
    m.BoxDecoration d;
    if (k == 'glass') {
      d = m.BoxDecoration(
        color: m.Colors.white.withOpacity(0.55),
        borderRadius: m.BorderRadius.circular(20),
        border: m.Border.all(color: m.Colors.white, width: 1.4),
        boxShadow: const [m.BoxShadow(color: m.Colors.black12, blurRadius: 12, offset: m.Offset(0, 4))],
      );
    } else if (k == '3d') {
      d = m.BoxDecoration(
        gradient: const m.LinearGradient(begin: m.Alignment.topLeft, end: m.Alignment.bottomRight, colors: [m.Color(0xFFFFFFFF), m.Color(0xFFE3DFF0)]),
        borderRadius: m.BorderRadius.circular(22),
        boxShadow: const [
          m.BoxShadow(color: m.Color(0x55311B92), blurRadius: 16, offset: m.Offset(7, 9)),
          m.BoxShadow(color: m.Colors.white, blurRadius: 10, offset: m.Offset(-5, -5)),
        ],
      );
    } else {
      d = m.BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: m.BorderRadius.circular(16),
        boxShadow: const [m.BoxShadow(color: m.Colors.black12, blurRadius: 6, offset: m.Offset(0, 2))],
      );
    }
    return m.Container(
      margin: margin ?? const m.EdgeInsets.all(4),
      decoration: d,
      child: m.Material(type: m.MaterialType.transparency, child: child),
    );
  }
}
