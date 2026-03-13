import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _selectedItems = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryFilter;
  String _selectedOccasion = 'Casual';
  bool _isLoading = true;
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _occasions = [
    'Casual', 'Công sở', 'Đi tiệc', 'Thể thao', 'Streetwear', 'Hẹn hò'
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _db.queryAllItems(),
        _db.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _allItems = results[0];
          _categories = results[1];
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategoryFilter == null) return _allItems;
    return _allItems
        .where((item) => item['categoryName'] == _selectedCategoryFilter)
        .toList();
  }

  bool _isSelected(Map<String, dynamic> item) {
    return _selectedItems.any((s) => s['id'] == item['id']);
  }

  void _toggleItem(Map<String, dynamic> item) {
    setState(() {
      if (_isSelected(item)) {
        _selectedItems.removeWhere((s) => s['id'] == item['id']);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  Future<void> _saveOutfit() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Vui lòng đặt tên cho bộ đồ!');
      return;
    }
    if (_selectedItems.isEmpty) {
      _showSnack('Chọn ít nhất 1 món đồ!');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _db.createOutfitWithItems(
        name: _nameController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        occasion: _selectedOccasion,
        items: _selectedItems
            .map((item) => {
                  'itemId': item['id'],
                  'position': item['categoryName'] ?? 'other',
                })
            .toList(),
      );

      if (mounted) {
        Navigator.pop(context, true); // trả về true để refresh
      }
    } catch (e) {
      _showSnack('Lỗi khi lưu: $e');
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildOutfitNameSection(),
                  _buildSelectedStrip(),
                  _buildCategoryFilter(),
                  Expanded(child: _buildItemGrid()),
                ],
              ),
            ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF7F5F2),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'TẠO BỘ TRANG PHỤC',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: Colors.black,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildOutfitNameSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            decoration: const InputDecoration(
              hintText: 'Tên bộ đồ...',
              hintStyle: TextStyle(color: Colors.black26, fontSize: 22),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.tag, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Wrap(
                spacing: 6,
                children: _occasions.map((occ) {
                  final selected = _selectedOccasion == occ;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedOccasion = occ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.transparent,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.black26,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        occ,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : Colors.black54,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedStrip() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _selectedItems.isEmpty ? 0 : 108,
      color: Colors.black,
      child: _selectedItems.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    '${_selectedItems.length} MÓN ĐỒ ĐÃ CHỌN',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _selectedItems.length,
                    itemBuilder: (ctx, i) =>
                        _buildSelectedChip(_selectedItems[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedChip(Map<String, dynamic> item) {
    final imageFile = File(item['image_path'] ?? '');
    return GestureDetector(
      onTap: () => _toggleItem(item),
      child: Container(
        width: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageFile.existsSync()
                  ? Image.file(imageFile,
                      width: 56, height: 56, fit: BoxFit.cover)
                  : Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[800],
                      child: const Icon(Icons.checkroom,
                          color: Colors.white54, size: 20),
                    ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 44,
      color: const Color(0xFFF7F5F2),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _filterChip('Tất cả', null),
          ..._categories
              .map((c) => _filterChip(c['categoryName'], c['categoryName'])),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _selectedCategoryFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.black : Colors.black12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildItemGrid() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Không có món đồ nào',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildItemTile(items[i]),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final selected = _isSelected(item);
    final imageFile = File(item['image_path'] ?? '');

    return GestureDetector(
      onTap: () => _toggleItem(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected
              ? [
                  const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: imageFile.existsSync()
                    ? Image.file(imageFile, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.checkroom,
                            color: Colors.grey, size: 36),
                      ),
              ),
              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Checkmark
              if (selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveOutfit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              disabledBackgroundColor: Colors.black54,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedItems.isEmpty
                            ? 'CHỌN ĐỒ ĐỂ TẠO BỘ'
                            : 'LƯU BỘ TRANG PHỤC (${_selectedItems.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}