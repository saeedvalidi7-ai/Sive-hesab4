import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text, Card;
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as im;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'util.dart';

Future<void> shareBoundary(GlobalKey key, String format, String name) async {
  final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await b.toImage(pixelRatio: 3);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List png = bd!.buffer.asUint8List();
  final dir = await getTemporaryDirectory();
  final path = p.join(dir.path, '$name.$format');
  if (format == 'pdf') {
    final doc = pw.Document();
    final mi = pw.MemoryImage(png);
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Center(child: pw.Image(mi))));
    await File(path).writeAsBytes(await doc.save());
  } else if (format == 'jpg') {
    final decoded = im.decodePng(png);
    await File(path).writeAsBytes(im.encodeJpg(decoded!, quality: 92));
  } else {
    await File(path).writeAsBytes(png);
  }
  await Share.shareXFiles([XFile(path)]);
}

class ExportBar extends StatelessWidget {
  final GlobalKey boundary;
  final String name;
  const ExportBar({super.key, required this.boundary, required this.name});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        for (final f in const ['pdf', 'png', 'jpg'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.tonal(onPressed: () => shareBoundary(boundary, f, name), child: Text('ارسال ${f.toUpperCase()}')),
            ),
          ),
      ]),
    );
  }
}
