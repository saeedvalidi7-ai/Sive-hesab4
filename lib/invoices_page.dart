import 'dart:io';
import 'package:flutter/material.dart' hide Text, Card;
import 'db.dart';
import 'export.dart';
import 'products_page.dart';
import 'util.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  List<Map<String, dynamic>> list = [];
  bool buy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Db.q(
        "SELECT i.*, c.name cname FROM invoices i LEFT JOIN customers c ON c.id=i.customer_id WHERE COALESCE(i.type,'sale')=? ORDER BY i.id DESC",
        [buy ? 'buy' : 'sale']);
    if (mounted) setState(() => list = r);
  }

  @override
  Widget build(BuildContext context) {
    final sum = list.fold<double>(0, (s, e) => s + (e['total'] as num));
    final com = list.fold<double>(0, (s, e) => s + ((e['commission'] as num?) ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('فاکتورها')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => NewInvoice(buy: buy)));
            load();
          },
          icon: const Icon(Icons.add),
          label: Text(buy ? 'فاکتور خرید جدید' : 'فاکتور فروش جدید')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('فروش')),
              ButtonSegment(value: true, label: Text('خرید')),
            ],
            selected: {buy},
            onSelectionChanged: (s) {
              buy = s.first;
              load();
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Text(buy ? 'جمع خرید: ${money(sum)}' : 'کل فروش: ${money(sum)}'),
              if (!buy) Text('پورسانت: ${money(com)}'),
            ]),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('هنوز فاکتوری ثبت نشده است'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceView(id: e['id'] as int)));
                          load();
                        },
                        title: Text('فاکتور ${e['id']} | ${e['cname'] ?? ''}'),
                        subtitle: Text('${e['date']}'),
                        trailing: Text('${money(e['total'] as num)}\nتومان', textAlign: TextAlign.center),
                      ),
                    );
                  }),
        ),
      ]),
    );
  }
}

class NewInvoice extends StatefulWidget {
  final bool buy;
  final int? editId;
  const NewInvoice({super.key, this.buy = false, this.editId});
  @override
  State<NewInvoice> createState() => _NewInvoiceState();
}

class _NewInvoiceState extends State<NewInvoice> {
  List<Map<String, dynamic>> customers = [], products = [];
  int? cid;
  bool buy = false;
  String? editDate;
  final lines = <Map<String, dynamic>>[];
  final disc = TextEditingController();
  final paid = TextEditingController();

  @override
  void initState() {
    super.initState();
    buy = widget.buy;
    load();
  }

  Future<void> load() async {
    final c = await Db.q('SELECT * FROM customers ORDER BY name');
    final pr = await Db.products();
    if (widget.editId != null) {
      final r = await Db.q('SELECT * FROM invoices WHERE id=?', [widget.editId]);
      final it = await Db.q('SELECT * FROM items WHERE invoice_id=?', [widget.editId]);
      final inv = r.first;
      buy = inv['type'] == 'buy';
      cid = inv['customer_id'] as int?;
      editDate = inv['date'] as String?;
      disc.text = fmt((inv['discount'] as num).toDouble());
      for (final e in it) {
        lines.add({
          'pid': e['product_id'],
          'name': e['name'],
          'unit': e['unit'],
          'qty': (e['qty'] as num).toDouble(),
          'price': (e['price'] as num).toDouble(),
          'disc': (e['disc'] as num).toDouble(),
        });
      }
    }
    if (mounted) {
      setState(() {
        customers = c;
        products = pr;
      });
    }
  }

  double lt(Map<String, dynamic> l) =>
      (l['qty'] as double) * (l['price'] as double) * (1 - (l['disc'] as double) / 100);
  double get sub => lines.fold(0.0, (s, l) => s + lt(l));
  double get total => sub - toNum(disc.text);

  void snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> addLine() async {
    if (products.isEmpty) {
      snack('اول در بخش انبار کالا ثبت کنید');
      return;
    }
    Map<String, dynamic> sel = products.first;
    num defPrice(Map<String, dynamic> p) => (buy ? p['buy'] : p['sell']) as num;
    final q = TextEditingController(text: '1');
    final pr = TextEditingController(text: fmt(defPrice(sel)));
    final d = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                  title: const Text('افزودن کالا'),
                  content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                        value: sel['id'] as int,
                        isExpanded: true,
                        items: products
                            .map((e) => DropdownMenuItem<int>(
                                value: e['id'] as int, child: Text('${e['name']} (${fmt(e['qty'] as num)} ${e['unit']})')))
                            .toList(),
                        onChanged: (v) => set(() {
                          sel = products.firstWhere((e) => e['id'] == v);
                          pr.text = fmt(defPrice(sel));
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد')),
                      const SizedBox(height: 8),
                      TextField(controller: pr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت واحد')),
                      const SizedBox(height: 8),
                      TextField(controller: d, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تخفیف ردیف (درصد)')),
                    ]),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('افزودن')),
                  ],
                )));
    if (ok == true && toNum(q.text) > 0) {
      setState(() => lines.add({
            'pid': sel['id'],
            'name': sel['name'],
            'unit': sel['unit'],
            'qty': toNum(q.text),
            'price': toNum(pr.text),
            'disc': toNum(d.text),
          }));
    }
  }

  Future<void> save() async {
    if (cid == null || lines.isEmpty) {
      snack('طرف حساب و حداقل یک کالا لازم است');
      return;
    }
    final pct = buy ? 0.0 : toNum(await Db.setting('commission'));
    final inv = <String, dynamic>{
      if (widget.editId != null) 'id': widget.editId,
      'customer_id': cid,
      'date': editDate ?? jalali(DateTime.now()),
      'type': buy ? 'buy' : 'sale',
      'subtotal': sub,
      'discount': toNum(disc.text),
      'total': total,
      'commission': total * pct / 100,
    };
    final items = lines
        .map((l) => <String, dynamic>{
              'product_id': l['pid'],
              'name': l['name'],
              'unit': l['unit'],
              'qty': l['qty'],
              'price': l['price'],
              'disc': l['disc'],
            })
        .toList();
    if (widget.editId != null) await Db.deleteInvoice(widget.editId!);
    final id = await Db.saveInvoice(inv, items, toNum(paid.text));
    Db.backup();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InvoiceView(id: id)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.editId != null ? 'ویرایش فاکتور ${widget.editId}' : (buy ? 'فاکتور خرید جدید' : 'فاکتور فروش جدید');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<int>(
          value: cid,
          isExpanded: true,
          decoration: InputDecoration(labelText: buy ? 'تأمین‌کننده (طرف حساب)' : 'مشتری'),
          items: customers.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text('${c['name']}'))).toList(),
          onChanged: (v) => setState(() => cid = v),
        ),
        if (customers.isEmpty)
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('ابتدا در بخش مشتریان یک طرف حساب ثبت کنید', style: TextStyle(color: Colors.red))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: addLine, icon: const Icon(Icons.add_shopping_cart), label: const Text('افزودن کالا')),
        ...lines.asMap().entries.map((e) {
          final l = e.value;
          return Card(
            child: ListTile(
              title: Text('${l['name']}'),
              subtitle: Text('${fmt(l['qty'] as double)} ${l['unit']} × ${money(l['price'] as double)}  تخفیف ${fmt(l['disc'] as double)}%'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(money(lt(l))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => lines.removeAt(e.key))),
              ]),
            ),
          );
        }),
        const SizedBox(height: 12),
        TextField(controller: disc, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'تخفیف کل فاکتور (تومان)')),
        const SizedBox(height: 12),
        if (widget.editId == null)
          TextField(controller: paid, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: buy ? 'مبلغ پرداختی همین لحظه (اختیاری)' : 'مبلغ دریافتی همین لحظه (اختیاری)')),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text('جمع: ${money(sub)}   |   مبلغ نهایی: ${money(total)} تومان', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        FilledButton(onPressed: save, child: Padding(padding: const EdgeInsets.all(12), child: Text(widget.editId != null ? 'ذخیرهٔ تغییرات' : 'صدور فاکتور'))),
      ]),
    );
  }
}

class InvoiceView extends StatefulWidget {
  final int id;
  const InvoiceView({super.key, required this.id});
  @override
  State<InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends State<InvoiceView> {
  final key = GlobalKey();
  Map<String, dynamic>? inv, cus;
  List<Map<String, dynamic>> items = [];
  final st = <String, String>{};
  double bal = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Db.q('SELECT * FROM invoices WHERE id=?', [widget.id]);
    final i = r.first;
    final c = await Db.q('SELECT * FROM customers WHERE id=?', [i['customer_id']]);
    final it = await Db.q('SELECT * FROM items WHERE invoice_id=?', [widget.id]);
    for (final k in ['company', 'phone', 'address', 'logo', 'stamp', 'sign']) {
      st[k] = await Db.setting(k);
    }
    final b = await Db.balance(i['customer_id'] as int);
    if (!mounted) return;
    setState(() {
      inv = i;
      cus = c.isEmpty ? null : c.first;
      items = it;
      bal = b;
    });
  }

  bool get isBuy => inv?['type'] == 'buy';

  Future<void> delInv() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('حذف فاکتور؟'),
              content: const Text('موجودی کالاها اصلاح می‌شود.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
              ],
            ));
    if (ok == true) {
      await Db.deleteInvoice(widget.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget img(String? path, double h) =>
      (path != null && path.isNotEmpty && File(path).existsSync()) ? Image.file(File(path), height: h) : const SizedBox();

  Widget cell(String t, {bool h = false}) => Padding(
        padding: const EdgeInsets.all(5),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: h ? FontWeight.bold : FontWeight.normal)),
      );

  Widget row2(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(b, style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  Widget paper() {
    final i = inv!;
    var n = 0;
    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          img(st['logo'], 60),
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
        Center(child: Text(isBuy ? 'فاکتور خرید' : 'فاکتور فروش', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black))),
        row2('شماره: ${i['id']}', 'تاریخ: ${i['date']}'),
        row2('${isBuy ? 'تأمین‌کننده' : 'مشتری'}: ${cus?['name'] ?? ''}', 'تلفن: ${cus?['phone'] ?? ''}'),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(color: Colors.black26),
          columnWidths: const {
            0: FixedColumnWidth(26),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.8),
            4: FlexColumnWidth(1),
            5: FlexColumnWidth(2),
          },
          children: [
            TableRow(decoration: const BoxDecoration(color: Color(0xFFEFE3C2)), children: [
              cell('ردیف', h: true), cell('شرح کالا', h: true), cell('تعداد', h: true),
              cell('قیمت', h: true), cell('٪', h: true), cell('جمع', h: true),
            ]),
            ...items.map((e) {
              n++;
              final qty = (e['qty'] as num).toDouble();
              final price = (e['price'] as num).toDouble();
              final d = (e['disc'] as num).toDouble();
              return TableRow(children: [
                cell('$n'), cell('${e['name']}'), cell('${fmt(qty)} ${e['unit']}'),
                cell(money(price)), cell(fmt(d)), cell(money(qty * price * (1 - d / 100))),
              ]);
            }),
          ],
        ),
        const SizedBox(height: 8),
        row2('جمع ردیف‌ها', '${money(i['subtotal'] as num)} تومان'),
        row2('تخفیف فاکتور', '${money(i['discount'] as num)} تومان'),
        row2('مبلغ نهایی', '${money(i['total'] as num)} تومان', bold: true),
        row2('مانده حساب', '${money(bal.abs())} تومان ${bal > 0 ? 'بدهکار' : bal < 0 ? 'بستانکار' : ''}', bold: true),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Column(children: [const Text('امضا', style: TextStyle(fontSize: 11, color: Colors.black)), img(st['sign'], 70)]),
          Column(children: [const Text('مهر شرکت', style: TextStyle(fontSize: 11, color: Colors.black)), img(st['stamp'], 80)]),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('فاکتور ${widget.id}'), actions: [
        IconButton(
            tooltip: 'ویرایش',
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NewInvoice(editId: widget.id))),
            icon: const Icon(Icons.edit)),
        IconButton(tooltip: 'حذف', onPressed: delInv, icon: const Icon(Icons.delete_outline)),
      ]),
      body: inv == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Center(child: RepaintBoundary(key: key, child: paper())),
                ),
              ),
              ExportBar(boundary: key, name: 'invoice_${widget.id}'),
            ]),
    );
  }
}
