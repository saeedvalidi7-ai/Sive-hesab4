import 'package:flutter/material.dart' hide Text, Card;
import 'db.dart';
import 'products_page.dart';
import 'util.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Map<String, dynamic>> list = [];
  Map<int, double> bal = {};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Db.q('SELECT * FROM customers ORDER BY id DESC');
    final m = <int, double>{};
    for (final c in r) {
      m[c['id'] as int] = await Db.balance(c['id'] as int);
    }
    if (!mounted) return;
    setState(() {
      list = r;
      bal = m;
    });
  }

  Future<void> add() async {
    final n = TextEditingController(), ph = TextEditingController(), ad = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('مشتری جدید'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: n, decoration: const InputDecoration(labelText: 'نام مشتری')),
                const SizedBox(height: 8),
                TextField(controller: ph, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'تلفن')),
                const SizedBox(height: 8),
                TextField(controller: ad, decoration: const InputDecoration(labelText: 'آدرس')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
              ],
            ));
    if (ok == true && n.text.trim().isNotEmpty) {
      await Db.ins('customers', {'name': n.text.trim(), 'phone': ph.text.trim(), 'address': ad.text.trim()});
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مشتریان')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: add, icon: const Icon(Icons.person_add), label: const Text('مشتری جدید')),
      body: list.isEmpty
          ? const Center(child: Text('هنوز مشتری ثبت نشده است'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final b = bal[c['id'] as int] ?? 0;
                return Card(
                  child: ListTile(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetail(c: c)));
                      load();
                    },
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF8BBD0), child: Icon(Icons.person)),
                    title: Text('${c['name']}'),
                    subtitle: Text('${c['phone']}'),
                    trailing: Text(
                        b > 0 ? 'بدهکار\n${money(b)}' : b < 0 ? 'بستانکار\n${money(-b)}' : 'تسویه',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: b > 0 ? Colors.red : Colors.green.shade700)),
                  ),
                );
              }),
    );
  }
}

class CustomerDetail extends StatefulWidget {
  final Map<String, dynamic> c;
  const CustomerDetail({super.key, required this.c});
  @override
  State<CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<CustomerDetail> {
  List<Map<String, dynamic>> rows = [];
  double bal = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = widget.c['id'] as int;
    final inv = await Db.q('SELECT id, date, total, type FROM invoices WHERE customer_id=?', [id]);
    final pay = await Db.q('SELECT id, date, amount, note FROM payments WHERE customer_id=?', [id]);
    final all = <Map<String, dynamic>>[
      for (final i in inv) {'t': '${i['type'] == 'buy' ? 'فاکتور خرید' : 'فاکتور فروش'} ${i['id']}', 'date': i['date'], 'amt': i['total'], 'debt': i['type'] != 'buy'},
      for (final p in pay) {'t': 'پرداخت', 'date': p['date'], 'amt': p['amount'], 'debt': false},
    ];
    all.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    final b = await Db.balance(id);
    if (!mounted) return;
    setState(() {
      rows = all;
      bal = b;
    });
  }

  Future<void> edit() async {
    final n = TextEditingController(text: '${widget.c['name']}');
    final ph = TextEditingController(text: '${widget.c['phone']}');
    final ad = TextEditingController(text: '${widget.c['address']}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('ویرایش مشتری'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: n, decoration: const InputDecoration(labelText: 'نام مشتری')),
                const SizedBox(height: 8),
                TextField(controller: ph, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'تلفن')),
                const SizedBox(height: 8),
                TextField(controller: ad, decoration: const InputDecoration(labelText: 'آدرس')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
              ],
            ));
    if (ok == true && n.text.trim().isNotEmpty) {
      await (await Db.get()).update('customers', {'name': n.text.trim(), 'phone': ph.text.trim(), 'address': ad.text.trim()},
          where: 'id=?', whereArgs: [widget.c['id']]);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> del() async {
    final id = widget.c['id'];
    final r = await Db.q('SELECT COUNT(*) c FROM invoices WHERE customer_id=?', [id]);
    if (!mounted) return;
    if ((r.first['c'] as int) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('این مشتری فاکتور دارد و قابل حذف نیست')));
      return;
    }
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('حذف مشتری؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
              ],
            ));
    if (ok == true) {
      final d = await Db.get();
      await d.delete('payments', where: 'customer_id=?', whereArgs: [id]);
      await d.delete('customers', where: 'id=?', whereArgs: [id]);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> pay() async {
    final a = TextEditingController(), n = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('ثبت پرداخت مشتری'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
                const SizedBox(height: 8),
                TextField(controller: n, decoration: const InputDecoration(labelText: 'توضیح')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
              ],
            ));
    if (ok == true && toNum(a.text) > 0) {
      await Db.ins('payments', {'customer_id': widget.c['id'], 'date': jalali(DateTime.now()), 'amount': toNum(a.text), 'note': n.text});
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.c['name']}'), actions: [
        IconButton(onPressed: edit, icon: const Icon(Icons.edit)),
        IconButton(onPressed: del, icon: const Icon(Icons.delete_outline)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: pay, icon: const Icon(Icons.payments), label: const Text('ثبت پرداخت')),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: Text(
                    'مانده حساب: ${money(bal.abs())} تومان ${bal > 0 ? '(بدهکار)' : bal < 0 ? '(بستانکار)' : ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ),
        ),
        Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                final debt = r['debt'] as bool;
                return Card(
                  child: ListTile(
                    title: Text('${r['t']}'),
                    subtitle: Text('${r['date']}'),
                    trailing: Text('${debt ? '+' : '-'}${money(r['amt'] as num)}',
                        style: TextStyle(color: debt ? Colors.red : Colors.green.shade700)),
                  ),
                );
              }),
        ),
      ]),
    );
  }
}
