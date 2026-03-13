import 'dart:io';
import 'package:flutter/material.dart';

class ItemDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailSheet({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final imageFile = File(item['image_path'] ?? '');
    final hex = item['colorHex'] as String? ?? '#CCCCCC';
    final color = _hexColor(hex);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        // Image hero
        Expanded(
          flex: 5,
          child: Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: imageFile.existsSync()
                    ? Image.file(imageFile, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFFF8F6F3),
                        child: Icon(Icons.checkroom_outlined, size: 80, color: Colors.grey.shade300),
                      ),
              ),
            ),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.white, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 16, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            // Category badge
            Positioned(
              top: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item['categoryName'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
            ),
          ]),
        ),
        // Details
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _InfoChip(
                    icon: Icons.circle,
                    iconColor: color,
                    label: item['colorName'] ?? 'Chưa chọn màu',
                  ),
                  const SizedBox(width: 10),
                  if (item['styleName'] != null)
                    _InfoChip(
                      icon: Icons.style_outlined,
                      iconColor: Colors.black,
                      label: item['styleName'],
                      filled: true,
                    ),
                ]),
                if (item['note'] != null && item['note'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6F3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['note'],
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Action buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'deleted'),
                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                      label: Text('Xóa', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                      label: const Text('Chỉnh sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool filled;

  const _InfoChip({
    required this.icon, required this.iconColor,
    required this.label, this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Colors.black : const Color(0xFFF8F6F3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: filled ? Colors.white : iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: filled ? Colors.white : Colors.black87,
          ),
        ),
      ]),
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