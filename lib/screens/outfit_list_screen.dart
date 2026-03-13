import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'outfit_builder_screen.dart';
import 'outfit_detail_screen.dart';

class OutfitListScreen extends StatefulWidget {
  const OutfitListScreen({super.key});

  @override
  State<OutfitListScreen> createState() => _OutfitListScreenState();
}

class _OutfitListScreenState extends State<OutfitListScreen> {
  final _db = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> _loadOutfits() => _db.getAllOutfits();

  Future<void> _openBuilder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OutfitBuilderScreen()),
    );
    if (result == true) setState(() {});
  }

  Future<void> _deleteOutfit(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bộ đồ?'),
        content: Text('Bạn có chắc muốn xóa "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteOutfit(id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'BỘ TRANG PHỤC',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: _openBuilder,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadOutfits(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.black));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          return _buildOutfitGrid(snapshot.data!);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBuilder,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'TẠO BỘ MỚI',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            child: Icon(Icons.style_outlined, size: 50, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa có bộ đồ nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phối đồ của bạn và lưu thành bộ',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openBuilder,
            icon: const Icon(Icons.add),
            label: const Text('Tạo bộ đồ đầu tiên'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitGrid(List<Map<String, dynamic>> outfits) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: outfits.length,
      itemBuilder: (ctx, i) => _buildOutfitCard(outfits[i]),
    );
  }

  Widget _buildOutfitCard(Map<String, dynamic> outfit) {
    final outfitId = outfit['id'] as int;
    final itemCount = outfit['itemCount'] as int? ?? 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OutfitDetailScreen(
              outfitId: outfitId,
              outfitName: outfit['name'],
            ),
          ),
        );
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _OutfitPreviewGrid(
                    outfitId: outfitId, db: _db),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          outfit['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _deleteOutfit(outfitId, outfit['name']),
                        child: Icon(Icons.more_vert,
                            size: 18, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _OccasionBadge(outfit['occasion'] ?? 'Casual'),
                      const Spacer(),
                      Text(
                        '$itemCount món',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
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
}

class _OccasionBadge extends StatelessWidget {
  final String occasion;
  const _OccasionBadge(this.occasion);

  Color get _color {
    switch (occasion) {
      case 'Công sở': return Colors.blue[700]!;
      case 'Đi tiệc': return Colors.purple[600]!;
      case 'Thể thao': return Colors.green[600]!;
      case 'Streetwear': return Colors.orange[700]!;
      case 'Hẹn hò': return Colors.pink[400]!;
      default: return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        occasion,
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Widget hiển thị lưới ảnh preview các item trong outfit
class _OutfitPreviewGrid extends StatelessWidget {
  final int outfitId;
  final DatabaseHelper db;

  const _OutfitPreviewGrid({required this.outfitId, required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.getItemsOfOutfit(outfitId),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            color: Colors.grey[100],
            child: Icon(Icons.style_outlined,
                size: 40, color: Colors.grey[300]),
          );
        }

        final items = snapshot.data!.take(4).toList();
        if (items.length == 1) {
          return _buildSingleImage(items[0]);
        }
        return GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: items.map((item) => _buildThumb(item)).toList(),
        );
      },
    );
  }

  Widget _buildSingleImage(Map<String, dynamic> item) {
    final f = File(item['image_path'] ?? '');
    return f.existsSync()
        ? Image.file(f, fit: BoxFit.cover)
        : Container(
            color: Colors.grey[200],
            child: const Icon(Icons.checkroom, color: Colors.grey));
  }

  Widget _buildThumb(Map<String, dynamic> item) {
    final f = File(item['image_path'] ?? '');
    return f.existsSync()
        ? Image.file(f, fit: BoxFit.cover)
        : Container(
            color: Colors.grey[200],
            child: const Icon(Icons.checkroom, color: Colors.grey, size: 18));
  }
}