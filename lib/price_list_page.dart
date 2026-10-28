import 'dart:io';
import 'package:flutter/material.dart' hide Text, Card;
import 'db.dart';
import 'export.dart';
import 'products_page.dart';
import 'util.dart';

class PriceListPage extends StatefulWidget {
  const PriceListPage({super.key});
  @override
  State<PriceListPage> createState() => _PriceListPageState();
}

class _PriceListPageState extends State<PriceListPage> {
  final key = GlobalKey();
  List<Map<String, dynamic>> all = [];
  final off = <int>{};
  String cat = 'همه';
  final st = <String, String>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final pr = await Db.products();
    for (final k in ['company', 'phone', 'address', 'logo']) {
      st[k] = await Db.setting(k);
    }
    if (mounted) setState(() => all = pr);
  }

  List<Map<String, dynamic>> get shown => all
      .where((p) => !off.contains(p['id'] as int) && (cat == 'همه' || (p['category'] ?? '').toString() == cat))
      .toList();

  List<String> get cats => [
        'همه',
        ...{for (final p in all) if ((p['category'] ?? '').toString().isNotEmpty) p['category'].toString()}
      ];

  Future<void> pickItems() async {
    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                  title: const Text('انتخاب کالاها'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView(shrinkWrap: true, children: [
                      for (final p in all)
                        CheckboxListTile(
                          value: !off.contains(p['id'] as int),
                          title: Text('${p['name']}'),
                          onChanged: (v) {
                            set(() {
                              if (v == true) {
                                off.remove(p['id'] as int);
                              } else {
                                off.add(p['id'] as int);
                              }
                            });
                            setState(() {});
                          },
                        ),
                    ]),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تأیید'))],
                )));
  }

  Widget cell(String t, {bool h = false}) => Padding(
        padding: const EdgeInsets.all(5),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: h ? FontWeight.bold : FontWeight.normal)),
      );

  Widget paper() {
    final rows = shown;
    final logo = st['logo'] ?? '';
    var n = 0;
    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (logo.isNotEmpty && File(logo).existsSync()) Image.file(File(logo), height: 60),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st['company'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(st['phone'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black)),
              Text(st['address'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black)),
            ]),
          ),
        ]),
        const Divider(),
        const Center(child: Text('لیست قیمت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))),
        Text('تاریخ: ${jalali(DateTime.now())}', style: const TextStyle(fontSize: 11, color: Colors.black)),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(color: Colors.black26),
          columnWidths: const {
            0: FixedColumnWidth(26),
            1: FixedColumnWidth(46),
            2: FlexColumnWidth(3),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(2.2),
          },
          children: [
            TableRow(decoration: const BoxDecoration(color: Color(0xFFEFE3C2)), children: [
              cell('ردیف', h: true), cell('عکس', h: true), cell('نام کالا', h: true), cell('واحد', h: true), cell('قیمت (تومان)', h: true),
            ]),
            ...rows.map((e) {
              n++;
              final img = e['image'] as String?;
              return TableRow(children: [
                cell('$n'),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: img != null && File(img).existsSync()
                      ? Image.file(File(img), height: 36, fit: BoxFit.cover)
                      : const SizedBox(height: 36),
                ),
                cell('${e['name']}'),
                cell('${e['unit']}'),
                cell(money(e['sell'] as num)),
              ]);
            }),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = cats;
    return Scaffold(
      appBar: AppBar(title: const Text('لیست قیمت‌ساز')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: cs.contains(cat) ? cat : 'همه',
                decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                items: cs.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => cat = v ?? 'همه'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: pickItems, icon: const Icon(Icons.checklist), label: const Text('انتخاب کالاها')),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(child: RepaintBoundary(key: key, child: paper())),
          ),
        ),
        ExportBar(boundary: key, name: 'price_list'),
      ]),
    );
  }
}
