// lib/screens/wardrobe_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../widgets/add_item_sheet.dart';

class WardrobeScreen extends StatefulWidget {
  @override
  _WardrobeScreenState createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final _db = DatabaseHelper.instance;

  void _showAddItemPopUp() {
    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc người dùng tương tác với bảng
      builder: (context) => AddItemPopUp(
        onSaved: () {
          setState(() {}); // Làm mới danh sách khi lưu thành công
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tủ Đồ Cá Nhân", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _db.queryAllItems(),
        builder: (context, snapshot) {
          // 1. Kiểm tra trạng thái đang kết nối
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          // 2. Kiểm tra nếu có lỗi xảy ra
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi hệ thống: ${snapshot.error}"));
          }

          // 3. Kiểm tra nếu dữ liệu rỗng (List rỗng [])
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text("Tủ đồ đang trống", style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                  Text("Bấm (+) để thêm món đồ đầu tiên", style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            );
          }

          // 4. Khi đã có dữ liệu thật sự
          final items = snapshot.data!;
          return GridView.builder(
            padding: EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildItemCard(items[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemPopUp,
        backgroundColor: Colors.black,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    // Kiểm tra file có tồn tại không để tránh lỗi đỏ màn hình
    final imageFile = File(item['image_path']);

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              child: imageFile.existsSync()
                  ? Image.file(imageFile, width: double.infinity, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? "Không tên",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  item['style'] ?? "Tự do",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}