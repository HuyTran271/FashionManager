import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

class DatabaseHelper {
  static const _databaseName = "SmartWardrobe.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    // KIỂM TRA VÀ KHỞI TẠO FACTORY CHO DESKTOP
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = "";
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Đối với Desktop, lưu file vào thư mục tài liệu
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      path = join(dbPath, _databaseName);
    } else {
      // Đối với Android/iOS
      path = join(await getDatabasesPath(), _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // Khởi tạo các bảng cho Module 1
    Future _onCreate(Database db, int version) async {
      await db.execute('''
        CREATE TABLE Categories (
          categoryId INTEGER PRIMARY KEY AUTOINCREMENT,
          categoryName TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE Colors (
          colorId INTEGER PRIMARY KEY AUTOINCREMENT,
          colorName TEXT NOT NULL UNIQUE
        )
      ''');

      await db.execute('''
        CREATE TABLE Items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_path TEXT NOT NULL,
          categoryId INTEGER NOT NULL,
          colorId INTEGER,
          style TEXT,
          FOREIGN KEY (categoryId) REFERENCES Categories (categoryId) ON DELETE RESTRICT,
          FOREIGN KEY (colorId) REFERENCES Colors (colorId)
        )
      ''');

    // Insert dữ liệu mẫu (Seed data) cho danh mục
    // 1. Chèn danh mục
      await db.rawInsert('INSERT INTO Categories (categoryName) VALUES ("Áo")');
      await db.rawInsert('INSERT INTO Categories (categoryName) VALUES ("Quần")');

      // 2. Chèn màu sắc mẫu
      await db.rawInsert('INSERT INTO Colors (colorName) VALUES ("Trắng")');

      // 3. CHÈN MÓN ĐỒ MẪU (Rất quan trọng để test UI)
      // Lưu ý: categoryId lấy là 1 (Áo), colorId là 1 (Trắng)
      await db.insert('Items', {
        'name': 'Áo sơ mi mẫu',
        'image_path': 'assets/images/test.png', // Đường dẫn tạm
        'categoryId': 1,
        'colorId': 1,
        'style': 'Công sở'
      });
  }

  // --- CÁC HÀM CRUD CƠ BẢN ---
  
  // Thêm mới 1 sản phẩm
  Future<int> insertItem(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('Items', row);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    Database db = await instance.database;
    return await db.query('Categories');
  }

  Future<List<Map<String, dynamic>>> getColors() async {
    Database db = await instance.database;
    return await db.query('Colors');
  }

  // Lấy toàn bộ danh sách sản phẩm
  // Future<List<Map<String, dynamic>>> queryAllItems() async {
  //   Database db = await instance.database;
  //   return await db.query('Items');
  // }

  Future<List<Map<String, dynamic>>> queryAllItems() async {
    Database db = await instance.database;
    // Sử dụng JOIN để lấy được categoryName và colorName thay vì chỉ lấy ID
    return await db.rawQuery('''
      SELECT 
        Items.*, 
        Categories.categoryName, 
        Colors.colorName 
      FROM Items
      LEFT JOIN Categories ON Items.categoryId = Categories.categoryId
      LEFT JOIN Colors ON Items.colorId = Colors.colorId
      ORDER BY Items.id DESC
    ''');
  }
}