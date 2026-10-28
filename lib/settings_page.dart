import 'dart:io';
import 'package:flutter/material.dart' hide Text, Card;
import 'package:share_plus/share_plus.dart';
import 'brand.dart';
import 'db.dart';
import 'util.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final company = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final commission = TextEditingController();
  String logo = '', stamp = '', sign = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    company.text = await Db.setting('company');
    phone.text = await Db.setting('phone');
    address.text = await Db.setting('address');
    commission.text = await Db.setting('commission');
    logo = await Db.setting('logo');
    stamp = await Db.setting('stamp');
    sign = await Db.setting('sign');
    if (mounted) setState(() {});
  }

  void snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> save() async {
    await Db.setSetting('company', company.text.trim());
    await Db.setSetting('phone', phone.text.trim());
    await Db.setSetting('address', address.text.trim());
    await Db.setSetting('commission', commission.text.trim());
    await Db.setSetting('logo', logo);
    await Db.setSetting('stamp', stamp);
    await Db.setSetting('sign', sign);
    snack('تنظیمات ذخیره شد');
  }

  Future<void> backupShare() async {
    final path = await Db.backup();
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> restore() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('بازیابی آخرین پشتیبان؟'),
              content: const Text('اطلاعات فعلی با آخرین نسخهٔ پشتیبان جایگزین می‌شود.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('بازیابی')),
              ],
            ));
    if (ok == true) {
      final r = await Db.restoreLatest();
      snack(r ? 'انجام شد. برنامه را ببندید و دوباره باز کنید.' : 'پشتیبانی پیدا نشد');
    }
  }

  Widget picker(String title, String path, void Function(String) set) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final r = await pickImagePath();
          if (r != null) setState(() => set(r));
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              path.isNotEmpty && File(path).existsSync() ? Image.file(File(path), height: 70) : const Icon(Icons.add_photo_alternate, size: 56),
              const SizedBox(height: 6),
              Text(title),
            ]),
          ),
        ),
      ),
    );
  }

  Widget f(String l, TextEditingController c, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('تم برنامه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final e in themeNames.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: themeNotifier.value == e.key,
              onSelected: (_) async {
                await Db.setSetting('theme', e.key);
                themeNotifier.value = e.key;
                setState(() {});
              },
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          picker('لوگو', logo, (v) => logo = v),
          picker('مهر', stamp, (v) => stamp = v),
          picker('امضا', sign, (v) => sign = v),
        ]),
        const SizedBox(height: 12),
        f('نام شرکت (سربرگ فاکتور)', company),
        f('تلفن', phone),
        f('آدرس', address),
        f('درصد پورسانت ویزیتور از هر فاکتور', commission, num: true),
        FilledButton(onPressed: save, child: const Padding(padding: EdgeInsets.all(12), child: Text('ذخیرهٔ تنظیمات'))),
        const Divider(height: 32),
        const Text('پشتیبان‌گیری', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Text('پشتیبان‌گیری خودکار هر بار باز و بسته شدن برنامه و صدور فاکتور انجام می‌شود (۷ نسخهٔ آخر).'),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: backupShare, icon: const Icon(Icons.cloud_upload), label: const Text('پشتیبان‌گیری و ارسال فایل')),
        OutlinedButton.icon(onPressed: restore, icon: const Icon(Icons.restore), label: const Text('بازیابی آخرین پشتیبان')),
      ]),
    );
  }
}
