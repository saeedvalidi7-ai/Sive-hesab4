import 'dart:io';
import 'package:flutter/material.dart' hide Text, Card;
import 'util.dart';
import 'price_list_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'db.dart';

const units = ['عدد', 'کارتن', 'بسته', 'کیلوگرم', 'گرم', 'متر', 'لیتر', 'جفت'];

double toNum(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  var t = s.replaceAll(',', '').replaceAll('٬', '').trim();
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(fa[i], '$i');
  }
  return double.tryParse(t) ?? 0;
}

String money(num n) => n.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
String fmt(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Map<String, dynamic>> all = [];
  String q = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Db.products();
    setState(() => all = r);
  }

  Future<void> open([Map<String, dynamic>? item]) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ProductForm(item: item)));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final list =
        all.where((e) => '${e['name']} ${e['code']}'.contains(q)).toList();
    final stockValue = list.fold<double>(
        0, (s, e) => s + (e['qty'] as num) * (e['buy'] as num));
    return Scaffold(
      appBar: AppBar(title: const Text('انبار و کالاها'), actions: [
        IconButton(
            tooltip: 'لیست قیمت',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceListPage())),
            icon: const Icon(Icons.price_change)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => open(),
          icon: const Icon(Icons.add),
          label: const Text('کالای جدید')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'جستجوی نام یا کد کالا', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Text('تعداد کالا: ${list.length}'),
              Text('ارزش انبار: ${money(stockValue)} تومان'),
            ]),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('هنوز کالایی ثبت نشده است'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final img = e['image'] as String?;
                    return Card(
                      child: ListTile(
                        onTap: () => open(e),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF8BBD0),
                          backgroundImage:
                              img != null && File(img).existsSync() ? FileImage(File(img)) : null,
                          child: img == null ? const Icon(Icons.inventory_2) : null,
                        ),
                        title: Text('${e['name']}'),
                        subtitle: Text(
                            'کد: ${e['code']}  |  موجودی: ${fmt(e['qty'] as num)} ${e['unit']}${(e['category'] ?? '').toString().isEmpty ? '' : '  |  ${e['category']}'}'),
                        trailing: Text('${money(e['sell'] as num)}\nتومان',
                            textAlign: TextAlign.center),
                      ),
                    );
                  }),
        ),
      ]),
    );
  }
}

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? item;
  const ProductForm({super.key, this.item});
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final name = TextEditingController();
  final qty = TextEditingController();
  final buy = TextEditingController();
  final sell = TextEditingController();
  final cat = TextEditingController();
  String unit = 'عدد';
  String? image;

  @override
  void initState() {
    super.initState();
    final e = widget.item;
    if (e != null) {
      name.text = e['name'];
      qty.text = fmt(e['qty'] as num);
      buy.text = fmt(e['buy'] as num);
      sell.text = fmt(e['sell'] as num);
      unit = e['unit'];
      image = e['image'];
      cat.text = (e['category'] ?? '').toString();
    }
  }

  Future<void> pick() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final f = await File(x.path).copy(
        p.join(dir.path, 'img_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    setState(() => image = f.path);
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('نام کالا را وارد کنید')));
      return;
    }
    await Db.save({
      if (widget.item != null) 'id': widget.item!['id'],
      if (widget.item != null) 'code': widget.item!['code'],
      'name': name.text.trim(),
      'unit': unit,
      'category': cat.text.trim(),
      'qty': toNum(qty.text),
      'buy': toNum(buy.text),
      'sell': toNum(sell.text),
      'image': image,
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> remove() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('حذف کالا؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
              ],
            ));
    if (ok == true) {
      await Db.remove(widget.item!['id'] as int);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget field(String label, TextEditingController c, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'کالای جدید' : 'ویرایش کالا'),
        actions: [
          if (widget.item != null)
            IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline))
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: GestureDetector(
            onTap: pick,
            child: CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFFF8BBD0),
              backgroundImage:
                  image != null && File(image!).existsSync() ? FileImage(File(image!)) : null,
              child: image == null ? const Icon(Icons.add_a_photo, size: 32) : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(widget.item == null ? 'کد کالا خودکار ساخته می‌شود' : 'کد: ${widget.item!['code']}')),
        const SizedBox(height: 16),
        field('نام کالا', name),
        field('دسته‌بندی کالا (مثلاً لوازم برقی)', cat),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: unit,
            decoration: const InputDecoration(labelText: 'واحد'),
            items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (v) => setState(() => unit = v ?? 'عدد'),
          ),
        ),
        field('موجودی اولیه', qty, number: true),
        field('قیمت خرید (تومان)', buy, number: true),
        field('قیمت فروش (تومان)', sell, number: true),
        FilledButton(onPressed: save, child: const Padding(padding: EdgeInsets.all(12), child: Text('ذخیره'))),
      ]),
    );
  }
}
