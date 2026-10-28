import 'package:flutter/material.dart' hide Text, Card;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'brand.dart';
import 'customers_page.dart';
import 'dashboard_page.dart';
import 'db.dart';
import 'invoices_page.dart';
import 'products_page.dart';
import 'settings_page.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final t = await Db.setting('theme');
  if (t.isNotEmpty && themeNames.containsKey(t)) themeNotifier.value = t;
  runApp(const SivaHesab());
}

class SivaHesab extends StatelessWidget {
  const SivaHesab({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (_, k, __) => MaterialApp(
        title: 'سیوا حساب',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(k),
        builder: (ctx, child) {
          final w = child ?? const SizedBox();
          if (k == 'glass') {
            return DecoratedBox(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB2EBF2), Color(0xFFE1BEE7), Color(0xFFFFE0B2)])),
                child: w);
          }
          if (k == '3d') {
            return DecoratedBox(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8EAF6), Color(0xFFB39DDB)])),
                child: w);
          }
          return w;
        },
        home: const Splash(next: Home()),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int i = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Db.backup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) Db.backup();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const ProductsPage(),
      const CustomersPage(),
      const InvoicesPage(),
      const SettingsPage(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (i != 0) {
          setState(() => i = 0);
          return;
        }
        final r = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('خروج از سیوا حساب'),
                  content: const Text('اطلاعات ذخیره (پشتیبان‌گیری) شود؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('خیر')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بله، ذخیره کن')),
                  ],
                ));
        if (r == true) await Db.backup();
        if (r != null) SystemNavigator.pop();
      },
      child: Scaffold(
        body: pages[i],
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'انبار'),
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'مشتریان'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'فاکتورها'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
          ],
        ),
      ),
    );
  }
}
