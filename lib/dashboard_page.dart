import 'package:flutter/material.dart' hide Text, Card;
import 'brand.dart';
import 'db.dart';
import 'invoices_page.dart';
import 'products_page.dart';
import 'util.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool daily = true;
  final stats = <MapEntry<String, String>>[];
  List<String> labels = [];
  List<double> vals = [];
  List<Map<String, dynamic>> topC = [], topP = [], cats = [];
  static const mn = ['فرو', 'ارد', 'خرد', 'تیر', 'مرد', 'شهر', 'مهر', 'آبا', 'آذر', 'دی', 'بهم', 'اسف'];
  static const cols = [Color(0xFF2E8B57), Color(0xFFB8860B), Color(0xFF00897B), Color(0xFF8E24AA), Color(0xFFD81B60), Color(0xFF1E88E5), Color(0xFFF4511E), Color(0xFF6D4C41)];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<double> sum(String where, List<Object?> a) async {
    final r = await Db.q("SELECT COALESCE(SUM(total),0) s FROM invoices WHERE COALESCE(type,'sale')='sale' AND ($where)", a);
    return (r.first['s'] as num).toDouble();
  }

  Future<int> cnt(String t) async => (await Db.q('SELECT COUNT(*) c FROM $t')).first['c'] as int;

  Future<void> load() async {
    final now = DateTime.now();
    final today = jalali(now);
    final week = List.generate(7, (i) => jalali(now.subtract(Duration(days: 6 - i))));
    final ym = today.substring(0, 7), y = today.substring(0, 4);
    final st = <MapEntry<String, String>>[
      MapEntry('فروش امروز', money(await sum('date=?', [today]))),
      MapEntry('فروش ۷ روز اخیر', money(await sum('date IN (${List.filled(7, '?').join(',')})', week))),
      MapEntry('فروش این ماه', money(await sum('date LIKE ?', ['$ym%']))),
      MapEntry('فروش امسال', money(await sum('date LIKE ?', ['$y%']))),
      MapEntry('تعداد فاکتور', '${await cnt('invoices')}'),
      MapEntry('تعداد مشتری', '${await cnt('customers')}'),
    ];
    final paid = (await Db.q('SELECT COALESCE(SUM(amount),0) s FROM payments')).first['s'] as num;
    st.add(MapEntry('مطالبات معوق', money(await sum('1=1', []) - paid.toDouble())));
    final com = (await Db.q('SELECT COALESCE(SUM(commission),0) s FROM invoices WHERE date LIKE ?', ['$ym%'])).first['s'] as num;
    st.add(MapEntry('پورسانت این ماه', money(com)));
    final lb = <String>[];
    final vl = <double>[];
    if (daily) {
      for (final d in week) {
        lb.add(d.substring(5));
        vl.add(await sum('date=?', [d]));
      }
    } else {
      for (var m = 1; m <= 12; m++) {
        lb.add(mn[m - 1]);
        vl.add(await sum('date LIKE ?', ['$y/${m.toString().padLeft(2, '0')}%']));
      }
    }
    final tc = await Db.q("SELECT c.name n, SUM(i.total) s FROM invoices i JOIN customers c ON c.id=i.customer_id WHERE COALESCE(i.type,'sale')='sale' GROUP BY c.id ORDER BY s DESC LIMIT 5");
    final tp = await Db.q("SELECT it.name n, SUM(it.qty*it.price*(1-it.disc/100)) s FROM items it JOIN invoices i ON i.id=it.invoice_id WHERE COALESCE(i.type,'sale')='sale' GROUP BY it.name ORDER BY s DESC LIMIT 5");
    final ct = await Db.q("SELECT COALESCE(NULLIF(p.category,''),'بدون دسته') n, SUM(it.qty*it.price*(1-it.disc/100)) s FROM items it JOIN invoices i ON i.id=it.invoice_id LEFT JOIN products p ON p.id=it.product_id WHERE COALESCE(i.type,'sale')='sale' GROUP BY n ORDER BY s DESC LIMIT 6");
    if (!mounted) return;
    setState(() {
      stats..clear()..addAll(st);
      labels = lb;
      vals = vl;
      topC = tc;
      topP = tp;
      cats = ct;
    });
  }

  Widget chart(BuildContext context) {
    final mx = vals.fold<double>(1, (a, b) => b > a ? b : a);
    final pr = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < vals.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: vals[i] / mx),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Container(
                  height: 120 * v + 2,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [pr, const Color(0xFFD4AF37)]),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: const TextStyle(fontSize: 10)),
            ]),
          ),
      ]),
    );
  }

  Widget rank(String title, List<Map<String, dynamic>> rows) {
    final mx = rows.fold<double>(1, (a, e) => (e['s'] as num) > a ? (e['s'] as num).toDouble() : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (rows.isEmpty) const Text('هنوز داده‌ای نیست'),
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text('${e['n']}')),
                  Text('${money(e['s'] as num)} تومان'),
                ]),
                const SizedBox(height: 3),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (e['s'] as num) / mx, minHeight: 8)),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('داشبورد مدیریت')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF0B3D2A), Color(0xFF2E8B57)]),
            ),
            child: Row(children: [
              const SivaLogo(size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('سیوا حساب', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('امروز ${jalali(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoice()));
                  load();
                },
                icon: const Icon(Icons.add),
                label: const Text('فاکتور جدید'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.9,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < stats.length; i++)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [cols[i % cols.length], cols[i % cols.length].withOpacity(0.65)]),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stats[i].key, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(stats[i].value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('نمودار فروش', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('روزانه')),
                      ButtonSegment(value: false, label: Text('ماهانه')),
                    ],
                    selected: {daily},
                    onSelectionChanged: (s) {
                      daily = s.first;
                      load();
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                if (vals.isNotEmpty) chart(context),
              ]),
            ),
          ),
          rank('پرفروش‌ترین کالاها', topP),
          rank('فروش بر اساس دسته‌بندی', cats),
          rank('بهترین مشتریان', topC),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
