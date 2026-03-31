import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ai_label_service.dart';
import '../services/database_helper.dart';

/// Shows AI predictions and lets user confirm/edit before saving item.
class AiAutofillSheet extends StatefulWidget {
  final String imagePath;

  const AiAutofillSheet({super.key, required this.imagePath});

  @override
  State<AiAutofillSheet> createState() => _AiAutofillSheetState();
}

class _AiAutofillSheetState extends State<AiAutofillSheet> {
  final _db = DatabaseHelper.instance;
  final _nameController = TextEditingController();

  AiLabelResult? _aiResult;
  bool _isAnalyzing = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _styles = [];
  List<Map<String, dynamic>> _colors = [];

  int? _selectedCategoryId;
  int? _selectedStyleId;
  int? _selectedColorId;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    _loadAndAnalyze();
  }

  Future<void> _loadAndAnalyze() async {
    final results = await Future.wait([
      _db.getCategories(),
      _db.getStyles(),
      _db.getColors(),
      AiLabelService.analyzeImage(widget.imagePath),
    ]);

    final categories = results[0] as List<Map<String, dynamic>>;
    final styles = results[1] as List<Map<String, dynamic>>;
    final colors = results[2] as List<Map<String, dynamic>>;
    final aiResult = results[3] as AiLabelResult?;

    if (!mounted) return;

    // Pre-select AI suggested category
    Map<String, dynamic>? matchedCat;
    if (aiResult != null) {
      matchedCat = categories.firstWhere(
        (c) => c['categoryName'] == aiResult.suggestedCategory,
        orElse: () => categories.first,
      );
    }

    Map<String, dynamic>? matchedStyle;
    if (aiResult?.suggestedStyle != null) {
      try {
        matchedStyle = styles.firstWhere(
          (s) => s['styleName'] == aiResult!.suggestedStyle,
        );
      } catch (_) {}
    }

    setState(() {
      _categories = categories;
      _styles = styles;
      _colors = colors;
      _aiResult = aiResult;
      _isAnalyzing = false;
      _selectedCategoryId = matchedCat?['categoryId'];
      _selectedCategoryName = matchedCat?['categoryName'];
      _selectedStyleId = matchedStyle?['styleId'];
      _nameController.text = aiResult?.suggestedName ?? '';
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Vui lòng nhập tên sản phẩm!');
      return;
    }
    if (_selectedCategoryId == null) {
      _showSnack('Vui lòng chọn danh mục!');
      return;
    }

    setState(() => _isSaving = true);
    await _db.insertItem({
      'name': _nameController.text.trim(),
      'image_path': widget.imagePath,
      'categoryId': _selectedCategoryId,
      'colorId': _selectedColorId,
      'styleId': _selectedStyleId,
    });

    if (mounted) Navigator.pop(context, true);
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
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text('AI AUTO-FILL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          )),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isAnalyzing
                ? _buildAnalyzingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImagePreview(),
                        const SizedBox(height: 16),
                        _buildAiBanner(),
                        const SizedBox(height: 20),
                        _buildNameField(),
                        const SizedBox(height: 16),
                        _buildCategorySelector(),
                        const SizedBox(height: 16),
                        _buildStyleSelector(),
                        const SizedBox(height: 16),
                        _buildColorSelector(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
          if (!_isAnalyzing) _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated AI icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (ctx, val, child) => Transform.scale(
              scale: val,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.amber, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('AI đang phân tích hình ảnh...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              )),
          const SizedBox(height: 8),
          Text('Nhận diện loại trang phục, màu sắc, phong cách',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE0DDD8),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final file = File(widget.imagePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: file.existsSync()
          ? Image.file(
              file,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            )
          : Container(
              height: 200,
              color: Colors.grey[200],
              child: const Icon(Icons.image, size: 60, color: Colors.grey),
            ),
    );
  }

  Widget _buildAiBanner() {
    if (_aiResult == null) return const SizedBox.shrink();
    final confidence = (_aiResult!.confidence * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF3A3A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Độ chính xác $confidence%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nhãn: ${_aiResult!.rawLabels.take(4).join(', ')}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('AI',
                style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return _section(
      label: 'TÊN SẢN PHẨM',
      child: TextField(
        controller: _nameController,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Tên trang phục...',
          hintStyle: const TextStyle(color: Colors.black26),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: const Icon(Icons.checkroom_outlined, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return _section(
      label: 'DANH MỤC',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _categories.map((c) {
          final selected = _selectedCategoryId == c['categoryId'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedCategoryId = c['categoryId'];
              _selectedCategoryName = c['categoryName'];
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected ? Colors.black : Colors.black12),
              ),
              child: Text(
                c['categoryName'],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return _section(
      label: 'PHONG CÁCH',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedStyleId = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _selectedStyleId == null ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _selectedStyleId == null
                        ? Colors.black
                        : Colors.black12),
              ),
              child: Text(
                'Không chọn',
                style: TextStyle(
                  color: _selectedStyleId == null ? Colors.white : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          ..._styles.map((s) {
            final selected = _selectedStyleId == s['styleId'];
            return GestureDetector(
              onTap: () => setState(() => _selectedStyleId = s['styleId']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? Colors.black : Colors.black12),
                ),
                child: Text(
                  s['styleName'],
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    return _section(
      label: 'MÀU SẮC',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _colors.map((c) {
          final selected = _selectedColorId == c['colorId'];
          Color? dotColor;
          try {
            final hex = (c['colorHex'] as String).replaceAll('#', '');
            dotColor = Color(int.parse('FF$hex', radix: 16));
          } catch (_) {}

          return GestureDetector(
            onTap: () => setState(() =>
                _selectedColorId = selected ? null : c['colorId']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dotColor ?? Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.black : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)]
                    : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3)],
              ),
              child: selected
                  ? Icon(Icons.check,
                      color: (dotColor?.computeLuminance() ?? 0) > 0.5
                          ? Colors.black
                          : Colors.white,
                      size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text(
                  'XÁC NHẬN & LƯU',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _section({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey[500],
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}