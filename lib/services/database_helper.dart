import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

class DatabaseHelper {
  static const _databaseName = "SmartWardrobe.db";
  static const _databaseVersion = 3;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      path = join(dbPath, _databaseName);
    } else {
      path = join(await getDatabasesPath(), _databaseName);
    }
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ─── Schema ──────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createBaseSchema(db);
    await _createV2Tables(db);
    await _createV3Tables(db);
    await _seedAll(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createV2Tables(db);
    if (oldVersion < 3) await _createV3Tables(db);
  }

  Future<void> _createBaseSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Categories (
        categoryId   INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryName TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Colors (
        colorId   INTEGER PRIMARY KEY AUTOINCREMENT,
        colorName TEXT NOT NULL UNIQUE,
        colorHex  TEXT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Styles (
        styleId   INTEGER PRIMARY KEY AUTOINCREMENT,
        styleName TEXT NOT NULL UNIQUE
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Items (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        image_path TEXT    NOT NULL,
        categoryId INTEGER NOT NULL,
        colorId    INTEGER,
        styleId    INTEGER,
        brand      TEXT,
        note       TEXT,
        createdAt  TEXT,
        FOREIGN KEY (categoryId) REFERENCES Categories(categoryId) ON DELETE RESTRICT,
        FOREIGN KEY (colorId)    REFERENCES Colors(colorId),
        FOREIGN KEY (styleId)    REFERENCES Styles(styleId)
      )''');
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Outfits (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT NOT NULL,
        note      TEXT,
        occasion  TEXT,
        createdAt TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS OutfitItems (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        outfitId INTEGER NOT NULL,
        itemId   INTEGER NOT NULL,
        position TEXT,
        FOREIGN KEY (outfitId) REFERENCES Outfits(id) ON DELETE CASCADE,
        FOREIGN KEY (itemId)   REFERENCES Items(id)   ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Schedules (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        outfitId      INTEGER,
        scheduledDate TEXT NOT NULL,
        eventName     TEXT,
        note          TEXT,
        isNotified    INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (outfitId) REFERENCES Outfits(id) ON DELETE SET NULL
      )''');
  }

  Future<void> _createV3Tables(Database db) async {
    // Styles table (if upgrading from v1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Styles (
        styleId   INTEGER PRIMARY KEY AUTOINCREMENT,
        styleName TEXT NOT NULL UNIQUE
      )''');
    // Safe ALTER columns for existing installations
    for (final sql in [
      'ALTER TABLE Colors ADD COLUMN colorHex TEXT',
      'ALTER TABLE Items ADD COLUMN styleId INTEGER REFERENCES Styles(styleId)',
      'ALTER TABLE Items ADD COLUMN brand TEXT',
      'ALTER TABLE Items ADD COLUMN note TEXT',
      'ALTER TABLE Items ADD COLUMN createdAt TEXT',
    ]) {
      try { await db.execute(sql); } catch (_) {}
    }
  }

  Future<void> _seedAll(Database db) async {
    // Categories
    for (final name in ['Áo', 'Quần', 'Giày', 'Phụ kiện', 'Váy / Đầm', 'Áo khoác']) {
      await db.rawInsert('INSERT OR IGNORE INTO Categories(categoryName) VALUES(?)', [name]);
    }
    // Colors with hex codes
    final colors = [
      ('Trắng', '#FFFFFF'), ('Đen', '#1C1C1E'), ('Xám', '#8E8E93'),
      ('Đỏ', '#FF3B30'), ('Hồng', '#FF2D55'), ('Cam', '#FF9500'),
      ('Vàng', '#FFCC00'), ('Xanh lá', '#34C759'), ('Xanh dương', '#007AFF'),
      ('Tím', '#AF52DE'), ('Nâu', '#A2845E'), ('Be / Kem', '#F5E6D3'),
    ];
    for (final c in colors) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO Colors(colorName, colorHex) VALUES(?,?)', [c.$1, c.$2]);
    }
    // Styles
    for (final s in ['Casual', 'Công sở', 'Đi tiệc', 'Thể thao', 'Streetwear',
                      'Hẹn hò', 'Dạo phố', 'Vintage', 'Minimalist', 'Bohemian']) {
      await db.rawInsert('INSERT OR IGNORE INTO Styles(styleName) VALUES(?)', [s]);
    }
  }

  // ─── Lookup tables ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async =>
      (await instance.database).query('Categories');

  Future<List<Map<String, dynamic>>> getColors() async =>
      (await instance.database).query('Colors', orderBy: 'colorId ASC');

  Future<List<Map<String, dynamic>>> getStyles() async =>
      (await instance.database).query('Styles', orderBy: 'styleId ASC');

  // ─── Items CRUD ───────────────────────────────────────────────────────────

  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    final data = Map<String, dynamic>.from(row);
    data['createdAt'] = DateTime.now().toIso8601String();
    return db.insert('Items', data);
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'];
    final data = Map<String, dynamic>.from(row)..remove('id');
    // Remove join-only fields that don't belong in Items table
    data.remove('categoryName');
    data.remove('colorName');
    data.remove('colorHex');
    data.remove('styleName');
    return db.update('Items', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return db.delete('Items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> queryAllItems({int? categoryId}) async {
    final db = await instance.database;
    final where = categoryId != null ? 'WHERE Items.categoryId = $categoryId' : '';
    return db.rawQuery('''
      SELECT Items.*, Categories.categoryName,
             Colors.colorName, Colors.colorHex,
             Styles.styleName
      FROM Items
      LEFT JOIN Categories ON Items.categoryId = Categories.categoryId
      LEFT JOIN Colors     ON Items.colorId    = Colors.colorId
      LEFT JOIN Styles     ON Items.styleId    = Styles.styleId
      $where
      ORDER BY Items.id DESC
    ''');
  }

  Future<Map<String, dynamic>?> getItemById(int id) async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT Items.*, Categories.categoryName,
             Colors.colorName, Colors.colorHex, Styles.styleName
      FROM Items
      LEFT JOIN Categories ON Items.categoryId = Categories.categoryId
      LEFT JOIN Colors     ON Items.colorId    = Colors.colorId
      LEFT JOIN Styles     ON Items.styleId    = Styles.styleId
      WHERE Items.id = ?
    ''', [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  // ─── Outfits CRUD ─────────────────────────────────────────────────────────

  Future<int> createOutfitWithItems({
    required String name,
    String? note,
    String? occasion,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await instance.database;
    int outfitId = 0;
    await db.transaction((txn) async {
      outfitId = await txn.insert('Outfits', {
        'name': name, 'note': note, 'occasion': occasion,
        'createdAt': DateTime.now().toIso8601String(),
      });
      for (final item in items) {
        await txn.insert('OutfitItems', {
          'outfitId': outfitId, 'itemId': item['itemId'], 'position': item['position'],
        });
      }
    });
    return outfitId;
  }

  Future<List<Map<String, dynamic>>> getAllOutfits() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT o.*, COUNT(oi.id) as itemCount
      FROM Outfits o
      LEFT JOIN OutfitItems oi ON o.id = oi.outfitId
      GROUP BY o.id ORDER BY o.createdAt DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getItemsOfOutfit(int outfitId) async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT Items.*, Categories.categoryName,
             Colors.colorName, Colors.colorHex, Styles.styleName,
             OutfitItems.position
      FROM OutfitItems
      JOIN  Items       ON OutfitItems.itemId    = Items.id
      LEFT JOIN Categories ON Items.categoryId  = Categories.categoryId
      LEFT JOIN Colors     ON Items.colorId     = Colors.colorId
      LEFT JOIN Styles     ON Items.styleId     = Styles.styleId
      WHERE OutfitItems.outfitId = ?
    ''', [outfitId]);
  }

  Future<int> deleteOutfit(int id) async =>
      (await instance.database).delete('Outfits', where: 'id = ?', whereArgs: [id]);

  // ─── Schedules CRUD ───────────────────────────────────────────────────────

  Future<int> insertSchedule(Map<String, dynamic> row) async =>
      (await instance.database).insert('Schedules', row);

  Future<int> updateSchedule(Map<String, dynamic> row) async =>
      (await instance.database).update('Schedules', row, where: 'id = ?', whereArgs: [row['id']]);

  Future<int> deleteSchedule(int id) async =>
      (await instance.database).delete('Schedules', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> getSchedulesByDate(DateTime date) async {
    final db = await instance.database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    return db.rawQuery('''
      SELECT s.*, o.name as outfitName, o.occasion as outfitOccasion
      FROM Schedules s LEFT JOIN Outfits o ON s.outfitId = o.id
      WHERE s.scheduledDate >= ? AND s.scheduledDate <= ?
      ORDER BY s.scheduledDate ASC
    ''', [start, end]);
  }

  Future<List<Map<String, dynamic>>> getSchedulesByMonth(int year, int month) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end   = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
    return db.rawQuery('''
      SELECT s.*, o.name as outfitName, o.occasion as outfitOccasion
      FROM Schedules s LEFT JOIN Outfits o ON s.outfitId = o.id
      WHERE s.scheduledDate >= ? AND s.scheduledDate <= ?
      ORDER BY s.scheduledDate ASC
    ''', [start, end]);
  }

  Future<Set<String>> getDatesWithSchedules(int year, int month) async {
    final list = await getSchedulesByMonth(year, month);
    return list.map((s) {
      final dt = DateTime.parse(s['scheduledDate']);
      return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
    }).toSet();
  }
}