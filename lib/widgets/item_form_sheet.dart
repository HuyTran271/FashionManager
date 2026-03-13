import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_helper.dart';

class ItemFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existingItem;

  const ItemFormSheet({super.key, this.existingItem});

  bool get isEditing => existingItem != null;

  @override
  State<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<ItemFormSheet> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _db = DatabaseHelper.instance;

  File? _image;
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _colors = [];
  List<Map<String, dynamic>> _styles = [];

  int? _selectedCategoryId;
  int? _selectedColorId;
  int? _selectedStyleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _db.getCategories(),
      _db.getColors(),
      _db.getStyles(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0];
      _colors = results[1];
      _styles = results[2];
      _isLoading = false;
    });

    // Pre-fill if editing
    final item = widget.existingItem;
    if (item != null) {
      _nameCtrl.text = item['name'] ?? '';
      _noteCtrl.text = item['note'] ?? '';
      _selectedCategoryId = item['categoryId'] as int?;
      _selectedColorId = item['colorId'] as int?;
      _selectedStyleId = item['styleId'] as int?;
      final path = item['image_path'] as String?;
      if (path != null && File(path).existsSync()) {
        _image = File(path);
      }
      setState(() {});
    } else {
      // Defaults for new item
      if (_categories.isNotEmpty) _selectedCategoryId = _categories[0]['categoryId'];
      if (_colors.isNotEmpty) _selectedColorId = _colors[0]['colorId'];
      setState(() {});
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final res = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (res != null && mounted) setState(() => _image = File(res.path));
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn ảnh', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _ImageSourceBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Chụp ảnh',
                  color: const Color(0xFF1A1A2E),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _ImageSourceBtn(
                  icon: Icons.photo_library_outlined,
                  label: 'Thư viện',
                  color: const Color(0xFF16213E),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập tên sản phẩm!'); return;
    }
    if (_selectedCategoryId == null) {
      _snack('Vui lòng chọn danh mục!'); return;
    }
    if (_image == null && !widget.isEditing) {
      _snack('Vui lòng chọn ảnh sản phẩm!'); return;
    }

    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'image_path': _image?.path ?? widget.existingItem?['image_path'] ?? '',
        'categoryId': _selectedCategoryId,
        'colorId': _selectedColorId,
        'styleId': _selectedStyleId,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      };

      if (widget.isEditing) {
        data['id'] = widget.existingItem!['id'];
        await _db.updateItem(data);
      } else {
        await _db.insertItem(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Lỗi: $e');
      setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F6F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSection(),
                      const SizedBox(height: 20),
                      _buildNameField(),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Danh mục'),
                      const SizedBox(height: 10),
                      _buildCategoryGrid(),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Màu sắc'),
                      const SizedBox(height: 10),
                      _buildColorPicker(),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Phong cách'),
                      const SizedBox(height: 10),
                      _buildStylePicker(),
                      const SizedBox(height: 20),
                      _buildNoteField(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              _buildSaveButton(),
            ]),
    );
  }

  Widget _buildHandle() => Container(
    margin: const EdgeInsets.only(top: 12),
    width: 40, height: 4,
    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: Row(children: [
      Text(
        widget.isEditing ? 'CHỈNH SỬA SẢN PHẨM' : 'THÊM SẢN PHẨM MỚI',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 18, color: Colors.black54),
        ),
      ),
    ]),
  );

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _image != null ? Colors.transparent : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: _image != null
            ? Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(_image!, width: double.infinity, height: 200, fit: BoxFit.cover),
                ),
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Đổi ảnh', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn ảnh sản phẩm', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Chụp ảnh hoặc chọn từ thư viện',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
      ),
    );
  }

  Widget _buildNameField() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: TextField(
      controller: _nameCtrl,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Tên sản phẩm...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        prefixIcon: Icon(Icons.drive_file_rename_outline, color: Colors.grey.shade400, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );

  Widget _buildSectionLabel(String label) => Text(
    label.toUpperCase(),
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.grey.shade500),
  );

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _categories.map((cat) {
        final selected = _selectedCategoryId == cat['categoryId'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCategoryId = cat['categoryId']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Colors.black : Colors.grey.shade200),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            child: Text(
              cat['categoryName'],
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10, runSpacing: 10,
          children: [
            ..._colors.map((c) {
              final colorId = c['colorId'] as int;
              final selected = _selectedColorId == colorId;
              final hex = c['colorHex'] as String? ?? '#CCCCCC';
              final color = _hexColor(hex);
              final isWhite = hex.toLowerCase() == '#ffffff';
              return GestureDetector(
                onTap: () => setState(() => _selectedColorId = colorId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : (isWhite ? Colors.grey.shade300 : Colors.transparent),
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
                        : [],
                  ),
                  child: selected
                      ? Icon(Icons.check, color: isWhite ? Colors.black : Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ],
        ),
        if (_selectedColorId != null) ...[
          const SizedBox(height: 10),
          Text(
            _colors.firstWhere((c) => c['colorId'] == _selectedColorId, orElse: () => {})['colorName'] ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildStylePicker() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _styles.map((s) {
        final styleId = s['styleId'] as int;
        final selected = _selectedStyleId == styleId;
        return GestureDetector(
          onTap: () => setState(() => _selectedStyleId = selected ? null : styleId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Colors.black : Colors.grey.shade200),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            child: Text(
              s['styleName'],
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoteField() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: TextField(
      controller: _noteCtrl,
      maxLines: 3,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Ghi chú thêm (tùy chọn)...',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Icon(Icons.notes_outlined, color: Colors.grey.shade400, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      ),
    ),
  );

  Widget _buildSaveButton() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            disabledBackgroundColor: Colors.black38,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(
                  widget.isEditing ? 'LƯU THAY ĐỔI' : 'THÊM SẢN PHẨM',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  ),
                ),
        ),
      ),
    ),
  );
}

// ── Image Source Button ──────────────────────────────────────────────────
class _ImageSourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}