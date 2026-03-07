import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_helper.dart';

class AddItemPopUp extends StatefulWidget {
  final VoidCallback onSaved;
  const AddItemPopUp({super.key, required this.onSaved});

  @override
  State<AddItemPopUp> createState() => _AddItemPopUpState();
}

class _AddItemPopUpState extends State<AddItemPopUp> {
  File? _image;
  final _nameController = TextEditingController();
  final _db = DatabaseHelper.instance;
  
  // 1. Khai báo danh sách để chứa dữ liệu thật
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _colors = [];
  bool _isLoading = true; // Biến trạng thái chờ

  int? _selectedCatId;
  String? _selectedColorName; 
  String _selectedStyle = "Casual";
  final List<String> _styles = ["Casual", "Công sở", "Đi tiệc", "Thể thao", "Streetwear"];

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Gọi hàm load dữ liệu ngay khi mở Pop-up
  }

  // 2. Hàm lấy dữ liệu từ SQLite
  Future<void> _loadInitialData() async {
    try {
      print("Đang tải dữ liệu từ DB..."); // Thêm log để debug

      // Sử dụng Future.wait để tải song song, nhanh hơn và an toàn hơn
      final results = await Future.wait([
        _db.getCategories(),
        _db.getColors(),
      ]).timeout(const Duration(seconds: 3)); // Giới hạn 3 giây, quá 3 giây sẽ văng lỗi

      final cats = results[0];
      final cols = results[1];

      print("Đã tải xong: ${cats.length} danh mục, ${cols.length} màu");

      if (mounted) { // Kiểm tra xem Widget còn trên màn hình không trước khi setState
        setState(() {
          _categories = cats;
          _colors = cols;
          _isLoading = false; // Tắt trạng thái chờ
          
          // Chọn giá trị mặc định nếu có dữ liệu
          if (_colors.isNotEmpty) _selectedColorName = _colors[0]['colorName'];
          if (_categories.isNotEmpty) _selectedCatId = _categories[0]['categoryId']; // Chọn sẵn danh mục đầu tiên
        });
      }
    } catch (e) {
      print("LỖI KHI TẢI DỮ LIỆU DB: $e");
      // QUAN TRỌNG: Dù có lỗi thì vẫn phải tắt trạng thái loading để UI hiện lên
      if (mounted) {
        setState(() {
          _isLoading = false; 
        });
        // Hiện thông báo lỗi cho người dùng
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tải dữ liệu: $e"))
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final res = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (res != null) setState(() => _image = File(res.path));
  }

  @override
  Widget build(BuildContext context) {
    // 3. Nếu đang load thì hiện vòng xoay, tránh lỗi null dữ liệu
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      title: const Center(child: Text("Thêm Sản Phẩm", style: TextStyle(fontWeight: FontWeight.bold))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phần chọn ảnh
              const Align(alignment: Alignment.centerLeft, child: Text("Ảnh sản phẩm:", style: TextStyle(fontSize: 13, color: Colors.black))),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Chụp ảnh"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Chọn từ thư viện"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_image != null)
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text("Chưa chọn ảnh")),
                ),

              const SizedBox(height: 10),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Tên sản phẩm", isDense: true)),

              // 4. DANH MỤC CHÍNH (Dữ liệu từ bảng Categories)
              DropdownButtonFormField<int>(
                value: _selectedCatId,
                decoration: const InputDecoration(labelText: "Danh mục chính"),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c['categoryId'] as int, // Lưu ý đúng tên cột trong DB
                  child: Text(c['categoryName'])
                )).toList(),
                onChanged: (val) => setState(() => _selectedCatId = val),
              ),

              const SizedBox(height: 15),
              const Align(alignment: Alignment.centerLeft, child: Text("Màu sắc:", style: TextStyle(fontSize: 13, color: Colors.black))),
              
              // 5. MÀU SẮC (Dữ liệu từ bảng Colors)
              Wrap(
                spacing: 5,
                children: _colors.map((c) {
                  final name = c['colorName'] as String;
                  return ChoiceChip(
                    label: Text(name, style: TextStyle(fontSize: 11, color: _selectedColorName == name ? Colors.white : Colors.black)),
                    selected: _selectedColorName == name,
                    selectedColor: Colors.black,
                    onSelected: (val) => setState(() => _selectedColorName = name),
                  );
                }).toList(),
              ),

              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedStyle,
                decoration: const InputDecoration(labelText: "Phong cách"),
                items: _styles.map((style) => DropdownMenuItem(
                  value: style,
                  child: Text(style),
                )).toList(),
                onChanged: (val) => setState(() => _selectedStyle = val!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.red))),
        ElevatedButton(
          onPressed: () async {
            // Kiểm tra điều kiện lưu
            if (_image == null || _nameController.text.isEmpty || _selectedCatId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng điền đủ thông tin!")));
              return;
            }

            // Tìm colorId từ colorName đã chọn
            final colorId = _colors.firstWhere((c) => c['colorName'] == _selectedColorName)['colorId'];

            // 6. LƯU VÀO DATABASE
            await _db.insertItem({
              'name': _nameController.text,
              'image_path': _image!.path,
              'categoryId': _selectedCatId,
              'colorId': colorId,
              'style': _selectedStyle,
            });

            widget.onSaved();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: const Text("THÊM", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}