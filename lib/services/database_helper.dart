import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

class DatabaseHelper {
  static const _databaseName = "SmartWardrobe_v3.db";
  static const _databaseVersion = 1;

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

  // ─── Schema ───────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createBaseSchema(db);
    await _createV2Tables(db);
    await _createV3Tables(db);
    await _createV4Tables(db);
    await _seedAll(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createV2Tables(db);
    if (oldVersion < 3) await _createV3Tables(db);
    if (oldVersion < 4) await _createV4Tables(db);
    if (oldVersion < 5) {
      try {
      await db.execute('ALTER TABLE CachedShoppingItems ADD COLUMN category TEXT');
      } catch (e) {
      print("Cột đã tồn tại hoặc có lỗi: $e");
      }
    }
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
        season     TEXT,
        minTemp    REAL,
        maxTemp    REAL,
        wearCount  INTEGER NOT NULL DEFAULT 0,
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
        minTemp   REAL,
        maxTemp   REAL,
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Styles (
        styleId   INTEGER PRIMARY KEY AUTOINCREMENT,
        styleName TEXT NOT NULL UNIQUE
      )''');
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

  Future<void> _createV4Tables(Database db) async {
    // Cache: weather & news
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CachedWeather (
        id          INTEGER PRIMARY KEY,
        city        TEXT,
        tempC       REAL,
        feelsLike   REAL,
        humidity    INTEGER,
        condition   TEXT,
        icon        TEXT,
        windKph     REAL,
        cachedAt    TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CachedNews (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT,
        description TEXT,
        url         TEXT,
        imageUrl    TEXT,
        source      TEXT,
        category    TEXT,
        publishedAt TEXT,
        cachedAt    TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CachedShoppingItems (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT,
        price       TEXT,
        imageUrl    TEXT,
        url         TEXT,
        brand       TEXT,
        category    TEXT,
        cachedAt    TEXT NOT NULL
      )''');
    // AI label history
    await db.execute('''
      CREATE TABLE IF NOT EXISTS AiLabelHistory (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath   TEXT,
        rawLabels   TEXT,
        suggestedCategory TEXT,
        suggestedStyle    TEXT,
        confirmedAt TEXT
      )''');
    // Wear log for recommendation engine
    await db.execute('''
      CREATE TABLE IF NOT EXISTS WearLog (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        outfitId  INTEGER,
        wornAt    TEXT NOT NULL,
        tempC     REAL,
        occasion  TEXT,
        FOREIGN KEY (outfitId) REFERENCES Outfits(id) ON DELETE SET NULL
      )''');
    // Safe migrations for existing installs
    for (final sql in [
      'ALTER TABLE Items ADD COLUMN season TEXT',
      'ALTER TABLE Items ADD COLUMN minTemp REAL',
      'ALTER TABLE Items ADD COLUMN maxTemp REAL',
      'ALTER TABLE Items ADD COLUMN wearCount INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE Outfits ADD COLUMN minTemp REAL',
      'ALTER TABLE Outfits ADD COLUMN maxTemp REAL',
    ]) {
      try { await db.execute(sql); } catch (_) {}
    }
  }

  Future<void> _seedAll(Database db) async {
    for (final name in ['Áo', 'Quần', 'Giày', 'Phụ kiện', 'Váy / Đầm', 'Áo khoác']) {
      await db.rawInsert(
          'INSERT OR IGNORE INTO Categories(categoryName) VALUES(?)', [name]);
    }
    final colors = [
      ('Trắng', '#FFFFFF'), ('Đen', '#1C1C1E'), ('Xám', '#8E8E93'),
      ('Đỏ', '#FF3B30'), ('Hồng', '#FF2D55'), ('Cam', '#FF9500'),
      ('Vàng', '#FFCC00'), ('Xanh lá', '#34C759'), ('Xanh dương', '#007AFF'),
      ('Tím', '#AF52DE'), ('Nâu', '#A2845E'), ('Be / Kem', '#F5E6D3'),
    ];
    for (final c in colors) {
      await db.rawInsert(
          'INSERT OR IGNORE INTO Colors(colorName, colorHex) VALUES(?,?)',
          [c.$1, c.$2]);
    }
    for (final s in [
      'Casual', 'Công sở', 'Đi tiệc', 'Thể thao', 'Streetwear',
      'Hẹn hò', 'Dạo phố', 'Vintage', 'Minimalist', 'Bohemian'
    ]) {
      await db.rawInsert(
          'INSERT OR IGNORE INTO Styles(styleName) VALUES(?)', [s]);
    }
  }

  // ─── Lookup tables ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async =>
      (await database).query('Categories');

  Future<List<Map<String, dynamic>>> getColors() async =>
      (await database).query('Colors', orderBy: 'colorId ASC');

  Future<List<Map<String, dynamic>>> getStyles() async =>
      (await database).query('Styles', orderBy: 'styleId ASC');

  // ─── Items CRUD ───────────────────────────────────────────────────────────

  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['createdAt'] = DateTime.now().toIso8601String();
    return db.insert('Items', data);
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await database;
    final id = row['id'];
    final data = Map<String, dynamic>.from(row)..remove('id');
    for (final k in ['categoryName', 'colorName', 'colorHex', 'styleName']) {
      data.remove(k);
    }
    return db.update('Items', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async =>
      (await database).delete('Items', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> queryAllItems({int? categoryId}) async {
    final db = await database;
    final where = categoryId != null ? 'WHERE Items.categoryId = $categoryId' : '';
    return db.rawQuery('''
      SELECT Items.*, Categories.categoryName,
             Colors.colorName, Colors.colorHex, Styles.styleName
      FROM Items
      LEFT JOIN Categories ON Items.categoryId = Categories.categoryId
      LEFT JOIN Colors     ON Items.colorId    = Colors.colorId
      LEFT JOIN Styles     ON Items.styleId    = Styles.styleId
      $where
      ORDER BY Items.id DESC
    ''');
  }

  Future<Map<String, dynamic>?> getItemById(int id) async {
    final db = await database;
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

  // ─── Wardrobe Stats ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWardrobeStats() async {
    final db = await database;
    final totalItems = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM Items')) ?? 0;
    final totalOutfits = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM Outfits')) ?? 0;
    final totalSchedules = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM Schedules WHERE scheduledDate >= ?',
            [DateTime.now().toIso8601String().substring(0, 10)])) ?? 0;
    final categoryBreakdown = await db.rawQuery('''
      SELECT c.categoryName, COUNT(i.id) as count
      FROM Categories c LEFT JOIN Items i ON c.categoryId = i.categoryId
      GROUP BY c.categoryId ORDER BY count DESC
    ''');
    return {
      'totalItems': totalItems,
      'totalOutfits': totalOutfits,
      'upcomingSchedules': totalSchedules,
      'categoryBreakdown': categoryBreakdown,
    };
  }

  // ─── Recommendation Engine ────────────────────────────────────────────────

  /// Returns outfit suggestions based on temperature and optional occasion
  Future<List<Map<String, dynamic>>> getRecommendedOutfits({
    required double tempC,
    String? occasion,
  }) async {
    final db = await database;
    // Temperature-based season: < 15°C = lạnh, 15-25 = mát, > 25 = nóng
    String tempFilter = '';
    if (tempC < 15) {
      tempFilter = "(o.minTemp IS NULL OR o.minTemp <= $tempC) "
          "AND (o.maxTemp IS NULL OR o.maxTemp >= $tempC)";
    } else if (tempC <= 25) {
      tempFilter = "(o.minTemp IS NULL OR o.minTemp <= 25)";
    } else {
      tempFilter = "(o.maxTemp IS NULL OR o.maxTemp >= 25)";
    }
    final occasionFilter = occasion != null
        ? "AND (o.occasion = '$occasion' OR o.occasion IS NULL)"
        : '';
    final outfits = await db.rawQuery('''
      SELECT o.*, COUNT(oi.id) as itemCount
      FROM Outfits o
      LEFT JOIN OutfitItems oi ON o.id = oi.outfitId
      WHERE $tempFilter $occasionFilter
      GROUP BY o.id
      ORDER BY o.createdAt DESC
      LIMIT 10
    ''');
    // Fallback: if no temp-matched outfits, return all recent
    if (outfits.isEmpty) {
      return db.rawQuery('''
        SELECT o.*, COUNT(oi.id) as itemCount
        FROM Outfits o LEFT JOIN OutfitItems oi ON o.id = oi.outfitId
        GROUP BY o.id ORDER BY o.createdAt DESC LIMIT 5
      ''');
    }
    return outfits;
  }

  /// Returns individual items suitable for current temperature
  Future<List<Map<String, dynamic>>> getRecommendedItems({
    required double tempC,
  }) async {
    final db = await database;
    String categoryFilter;
    if (tempC < 15) {
      // Cold: suggest coats, jackets
      categoryFilter = "AND (c.categoryName = 'Áo khoác' OR i.season = 'Đông')";
    } else if (tempC <= 22) {
      categoryFilter = "AND i.season != 'Hè'";
    } else {
      // Hot: avoid heavy items
      categoryFilter = "AND (c.categoryName != 'Áo khoác')";
    }
    return db.rawQuery('''
      SELECT i.*, c.categoryName, col.colorName, col.colorHex, s.styleName
      FROM Items i
      LEFT JOIN Categories c   ON i.categoryId = c.categoryId
      LEFT JOIN Colors     col ON i.colorId    = col.colorId
      LEFT JOIN Styles     s   ON i.styleId    = s.styleId
      WHERE 1=1 $categoryFilter
      ORDER BY i.wearCount ASC, i.id DESC
      LIMIT 12
    ''');
  }

  // ─── Outfits CRUD ─────────────────────────────────────────────────────────

  Future<int> createOutfitWithItems({
    required String name,
    String? note,
    String? occasion,
    double? minTemp,
    double? maxTemp,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    int outfitId = 0;
    await db.transaction((txn) async {
      outfitId = await txn.insert('Outfits', {
        'name': name, 'note': note, 'occasion': occasion,
        'minTemp': minTemp, 'maxTemp': maxTemp,
        'createdAt': DateTime.now().toIso8601String(),
      });
      for (final item in items) {
        await txn.insert('OutfitItems', {
          'outfitId': outfitId,
          'itemId': item['itemId'],
          'position': item['position'],
        });
      }
    });
    return outfitId;
  }

  Future<List<Map<String, dynamic>>> getAllOutfits() async {
    final db = await database;
    return db.rawQuery('''
      SELECT o.*, COUNT(oi.id) as itemCount
      FROM Outfits o LEFT JOIN OutfitItems oi ON o.id = oi.outfitId
      GROUP BY o.id ORDER BY o.createdAt DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getItemsOfOutfit(int outfitId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT i.*, c.categoryName, col.colorName, col.colorHex, s.styleName,
             oi.position
      FROM OutfitItems oi
      JOIN  Items i       ON oi.itemId    = i.id
      LEFT JOIN Categories c   ON i.categoryId = c.categoryId
      LEFT JOIN Colors     col ON i.colorId    = col.colorId
      LEFT JOIN Styles     s   ON i.styleId    = s.styleId
      WHERE oi.outfitId = ?
    ''', [outfitId]);
  }

  Future<int> deleteOutfit(int id) async =>
      (await database).delete('Outfits', where: 'id = ?', whereArgs: [id]);

  // ─── Schedules CRUD ───────────────────────────────────────────────────────

  Future<int> insertSchedule(Map<String, dynamic> row) async =>
      (await database).insert('Schedules', row);

  Future<int> updateSchedule(Map<String, dynamic> row) async =>
      (await database).update('Schedules', row,
          where: 'id = ?', whereArgs: [row['id']]);

  Future<int> deleteSchedule(int id) async =>
      (await database).delete('Schedules',
          where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> getSchedulesByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    return db.rawQuery('''
      SELECT s.*, o.name as outfitName, o.occasion as outfitOccasion
      FROM Schedules s LEFT JOIN Outfits o ON s.outfitId = o.id
      WHERE s.scheduledDate >= ? AND s.scheduledDate <= ?
      ORDER BY s.scheduledDate ASC
    ''', [start, end]);
  }

  Future<List<Map<String, dynamic>>> getSchedulesByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
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
      final dt = DateTime.parse(s['scheduledDate'] as String);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }).toSet();
  }

  // ─── Cache: Weather ───────────────────────────────────────────────────────

  Future<void> saveWeatherCache(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('CachedWeather', {
      'id': 1,
      ...data,
      'cachedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getWeatherCache({int maxAgeMinutes = 30}) async {
    final db = await database;
    final rows = await db.query('CachedWeather', where: 'id = 1');
    if (rows.isEmpty) return null;
    final row = rows.first;
    final cachedAt = DateTime.parse(row['cachedAt'] as String);
    if (DateTime.now().difference(cachedAt).inMinutes > maxAgeMinutes) return null;
    return row;
  }

  // ─── Cache: News ──────────────────────────────────────────────────────────

  Future<void> saveNewsCache(List<Map<String, dynamic>> articles) async {
    final db = await database;
    await db.delete('CachedNews');
    final now = DateTime.now().toIso8601String();
    for (final a in articles) {
      await db.insert('CachedNews', {...a, 'cachedAt': now});
    }
  }

  Future<List<Map<String, dynamic>>> getNewsCache({int maxAgeMinutes = 60}) async {
    final db = await database;
    final rows = await db.query('CachedNews', orderBy: 'id ASC', limit: 10);
    if (rows.isEmpty) return [];
    final cachedAt = DateTime.parse(rows.first['cachedAt'] as String);
    if (DateTime.now().difference(cachedAt).inMinutes > maxAgeMinutes) return [];
    return rows;
  }

  // ─── Cache: Shopping ─────────────────────────────────────────────────────

  Future<void> saveShoppingCache(List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.delete('CachedShoppingItems');
    final now = DateTime.now().toIso8601String();
    for (final item in items) {
      await db.insert('CachedShoppingItems', {...item, 'cachedAt': now});
    }
  }

  Future<List<Map<String, dynamic>>> getShoppingCache() async {
    final db = await database;
    return db.query('CachedShoppingItems', orderBy: 'id ASC', limit: 20);
  }

  // ─── AI Label History ─────────────────────────────────────────────────────

  Future<int> saveAiLabel(Map<String, dynamic> row) async =>
      (await database).insert('AiLabelHistory', {
        ...row,
        'confirmedAt': DateTime.now().toIso8601String(),
      });

  // ─── Wear Log ─────────────────────────────────────────────────────────────

  Future<void> logWear(int outfitId, double? tempC, String? occasion) async {
    final db = await database;
    await db.insert('WearLog', {
      'outfitId': outfitId,
      'wornAt': DateTime.now().toIso8601String(),
      'tempC': tempC,
      'occasion': occasion,
    });
    // Increment wearCount on all items in the outfit
    await db.rawUpdate('''
      UPDATE Items SET wearCount = wearCount + 1
      WHERE id IN (SELECT itemId FROM OutfitItems WHERE outfitId = ?)
    ''', [outfitId]);
  }
}