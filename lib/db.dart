import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Db {
  static Database? _db;
  static Future<Database> get() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'siva_hesab.db');
    _db = await openDatabase(path, version: 4, onCreate: (d, v) async {
      await _v1(d);
      await _v2(d);
      await _v3(d);
      await _v4(d);
    }, onUpgrade: (d, o, n) async {
      if (o < 2) await _v2(d);
      if (o < 3) await _v3(d);
      if (o < 4) await _v4(d);
    });
    return _db!;
  }

  static Future<void> _v1(Database d) => d.execute(
      'CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, name TEXT, unit TEXT, qty REAL, buy REAL, sell REAL, image TEXT)');

  static Future<void> _v4(Database d) => d.execute("ALTER TABLE invoices ADD COLUMN type TEXT DEFAULT 'sale'");

  static Future<void> _v3(Database d) => d.execute('ALTER TABLE products ADD COLUMN category TEXT');

  static Future<void> _v2(Database d) async {
    await d.execute(
        'CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, address TEXT)');
    await d.execute(
        'CREATE TABLE invoices(id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER, date TEXT, subtotal REAL, discount REAL, total REAL, commission REAL)');
    await d.execute(
        'CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER, product_id INTEGER, name TEXT, unit TEXT, qty REAL, price REAL, disc REAL)');
    await d.execute(
        'CREATE TABLE payments(id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER, date TEXT, amount REAL, note TEXT)');
    await d.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
  }

  static Future<List<Map<String, dynamic>>> q(String sql, [List<Object?>? a]) async =>
      (await get()).rawQuery(sql, a);
  static Future<int> ins(String t, Map<String, dynamic> m) async =>
      (await get()).insert(t, m);

  static Future<List<Map<String, dynamic>>> products() async =>
      (await get()).query('products', orderBy: 'id DESC');

  static Future<void> save(Map<String, dynamic> p) async {
    final d = await get();
    if (p['id'] == null) {
      final id = await d.insert('products', p);
      final code = 'P${id.toString().padLeft(4, '0')}';
      await d.update('products', {'code': code}, where: 'id=?', whereArgs: [id]);
    } else {
      await d.update('products', p, where: 'id=?', whereArgs: [p['id']]);
    }
  }

  static Future<void> remove(int id) async =>
      (await get()).delete('products', where: 'id=?', whereArgs: [id]);

  static Future<String> setting(String k) async {
    final r = await q('SELECT v FROM settings WHERE k=?', [k]);
    return r.isEmpty ? '' : (r.first['v'] as String? ?? '');
  }

  static Future<void> setSetting(String k, String v) async =>
      (await get()).insert('settings', {'k': k, 'v': v},
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<double> balance(int cid) async {
    final a = await q("SELECT COALESCE(SUM(CASE WHEN COALESCE(type,'sale')='buy' THEN -total ELSE total END),0) s FROM invoices WHERE customer_id=?", [cid]);
    final b = await q('SELECT COALESCE(SUM(amount),0) s FROM payments WHERE customer_id=?', [cid]);
    return (a.first['s'] as num).toDouble() - (b.first['s'] as num).toDouble();
  }

  static Future<int> saveInvoice(Map<String, dynamic> inv,
      List<Map<String, dynamic>> items, double paid) async {
    final d = await get();
    return d.transaction((t) async {
      final id = await t.insert('invoices', inv);
      for (final it in items) {
        await t.insert('items', {...it, 'invoice_id': id});
        if (it['product_id'] != null) {
          await t.rawUpdate('UPDATE products SET qty = qty ${inv['type'] == 'buy' ? '+' : '-'} ? WHERE id=?',
              [it['qty'], it['product_id']]);
        }
      }
      if (paid > 0) {
        await t.insert('payments', {
          'customer_id': inv['customer_id'],
          'date': inv['date'],
          'amount': inv['type'] == 'buy' ? -paid : paid,
          'note': 'پرداخت هنگام صدور فاکتور $id'
        });
      }
      return id;
    });
  }

  static Future<void> deleteInvoice(int id) async {
    final d = await get();
    await d.transaction((t) async {
      final invr = await t.query('invoices', where: 'id=?', whereArgs: [id]);
      final isBuy = invr.isNotEmpty && invr.first['type'] == 'buy';
      final its = await t.query('items', where: 'invoice_id=?', whereArgs: [id]);
      for (final it in its) {
        if (it['product_id'] != null) {
          await t.rawUpdate('UPDATE products SET qty = qty ${isBuy ? '-' : '+'} ? WHERE id=?', [it['qty'], it['product_id']]);
        }
      }
      await t.delete('items', where: 'invoice_id=?', whereArgs: [id]);
      await t.delete('invoices', where: 'id=?', whereArgs: [id]);
    });
  }

  static Future<Directory> _bdir() async {
    final dir = Directory(join((await getApplicationDocumentsDirectory()).path, 'backups'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<String> backup() async {
    final src = join(await getDatabasesPath(), 'siva_hesab.db');
    final dir = await _bdir();
    final out = join(dir.path, 'siva_${DateTime.now().millisecondsSinceEpoch}.db');
    await File(src).copy(out);
    final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    while (files.length > 7) {
      files.removeAt(0).deleteSync();
    }
    return out;
  }

  static Future<bool> restoreLatest() async {
    final dir = await _bdir();
    final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) return false;
    await _db?.close();
    _db = null;
    await files.last.copy(join(await getDatabasesPath(), 'siva_hesab.db'));
    return true;
  }
}
