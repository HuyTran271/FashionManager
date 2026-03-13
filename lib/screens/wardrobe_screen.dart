import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../widgets/item_form_sheet.dart';
import '../widgets/item_detail_sheet.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _isGridView = true;
  bool _isLoading = true;

  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadData();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fabAnimController.forward());
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
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
          _items = results[0];
          _categories = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategoryId == null) return _items;
    return _items
        .where((item) => item['categoryId'] == _selectedCategoryId)
        .toList();
  }

  // ─── Add / Edit ───────────────────────────────────────────────────────────

  Future<void> _openAddForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ItemFormSheet(),
    );
    if (result == true) _loadData();
  }

  Future<void> _openEditForm(Map<String, dynamic> item) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemFormSheet(existingItem: item),
    );
    if (result == true) _loadData();
  }

  // ─── Detail ───────────────────────────────────────────────────────────────

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(item: item),
    );
    if (result == 'edit') {
      _openEditForm(item);
    } else if (result == 'deleted') {
      _loadData();
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline,
                  color: Colors.red[400], size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Xóa sản phẩm?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn xóa "${item['name']}"?\nHành động này không thể hoàn tác.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: const Text('Hủy',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Xóa',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteItem(item['id']);
      _loadData();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          _buildSliverAppBar(innerBoxIsScrolled),
          SliverToBoxAdapter(child: _buildCategoryFilter()),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black))
            : _buildItemsView(),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
            parent: _fabAnimController, curve: Curves.elasticOut),
        child: FloatingActionButton(
          onPressed: _openAddForm,
          backgroundColor: Colors.black,
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(bool innerBoxIsScrolled) {
    final filtered = _filteredItems;
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: AnimatedOpacity(
          opacity: innerBoxIsScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'TỦ ĐỒ (${filtered.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
        ),
        background: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TỦ ĐỒ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '${filtered.length} sản phẩm',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Grid/List toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EEE9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _toggleButton(
                        Icons.grid_view_rounded, true, _isGridView),
                    _toggleButton(
                        Icons.view_list_rounded, false, _isGridView),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleButton(IconData icon, bool isGrid, bool currentIsGrid) {
    final selected = isGrid == currentIsGrid;
    return GestureDetector(
      onTap: () => setState(() => _isGridView = isGrid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18, color: selected ? Colors.white : Colors.grey[500]),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EEE9)),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _categoryChip('Tất cả', null),
                ..._categories.map(
                  (c) => _categoryChip(c['categoryName'], c['categoryId']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, int? id) {
    final selected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildItemsView() {
    final items = _filteredItems;
    if (items.isEmpty) return _buildEmptyState();
    return _isGridView ? _buildGrid(items) : _buildList(items);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            child: Icon(Icons.checkroom_outlined,
                size: 44, color: Colors.grey[350]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tủ đồ trống',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm trang phục đầu tiên của bạn',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddForm,
            icon: const Icon(Icons.add),
            label: const Text('Thêm sản phẩm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Grid view ────────────────────────────────────────────────────────────

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildGridCard(items[i]),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> item) {
    final imageFile = File(item['image_path'] ?? '');
    final colorHex = item['colorHex'] as String?;
    final styleName = item['styleName'] as String?;

    return GestureDetector(
      onTap: () => _openDetail(item),
      onLongPress: () => _showContextMenu(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              child: Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: imageFile.existsSync()
                        ? Image.file(imageFile,
                            width: double.infinity, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFF0EEE9),
                            child: Icon(Icons.checkroom,
                                color: Colors.grey[300], size: 48),
                          ),
                  ),
                  // Style badge top-left
                  if (styleName != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          styleName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  // More options top-right
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _showContextMenu(item),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.more_horiz,
                            size: 16, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item['categoryName'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      if (colorHex != null) _colorDot(colorHex),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List view ────────────────────────────────────────────────────────────

  Widget _buildList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildListTile(items[i]),
    );
  }

  Widget _buildListTile(Map<String, dynamic> item) {
    final imageFile = File(item['image_path'] ?? '');
    final colorHex = item['colorHex'] as String?;
    final styleName = item['styleName'] as String?;

    return GestureDetector(
      onTap: () => _openDetail(item),
      onLongPress: () => _showContextMenu(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: imageFile.existsSync()
                  ? Image.file(imageFile,
                      width: 90, height: 90, fit: BoxFit.cover)
                  : Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFF0EEE9),
                      child: Icon(Icons.checkroom,
                          color: Colors.grey[300], size: 32),
                    ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['categoryName'] ?? '',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (styleName != null || colorHex != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (styleName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                styleName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (colorHex != null) ...[
                            const SizedBox(width: 6),
                            _colorDot(colorHex),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: Colors.grey[400],
                  onPressed: () => _openEditForm(item),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red[300],
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ─── Context menu (long press) ────────────────────────────────────────────

  void _showContextMenu(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item['name'] ?? '',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _menuTile(
              icon: Icons.visibility_outlined,
              label: 'Xem chi tiết',
              onTap: () {
                Navigator.pop(ctx);
                _openDetail(item);
              },
            ),
            _menuTile(
              icon: Icons.edit_outlined,
              label: 'Chỉnh sửa',
              onTap: () {
                Navigator.pop(ctx);
                _openEditForm(item);
              },
            ),
            _menuTile(
              icon: Icons.delete_outline,
              label: 'Xóa sản phẩm',
              color: Colors.red[400]!,
              onTap: () {
                Navigator.pop(ctx);
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _colorDot(String hex) {
    Color? c;
    try {
      final h = hex.replaceAll('#', '');
      c = Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c ?? Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 1),
      ),
    );
  }
}