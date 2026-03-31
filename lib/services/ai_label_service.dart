import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'database_helper.dart';

class AiLabelResult {
  final String suggestedCategory;
  final String? suggestedStyle;
  final String? suggestedName;
  final List<String> rawLabels;
  final double confidence;

  const AiLabelResult({
    required this.suggestedCategory,
    this.suggestedStyle,
    this.suggestedName,
    required this.rawLabels,
    required this.confidence,
  });
}

class AiLabelService {
  static ImageLabeler? _labeler;

  static ImageLabeler _getLabeler() {
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    return _labeler!;
  }

  static Future<AiLabelResult?> analyzeImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      final labeler = _getLabeler();
      final labels = await labeler.processImage(inputImage);

      final rawLabels = labels.map((l) => l.label.toLowerCase()).toList();
      final confidence = labels.isNotEmpty ? labels.first.confidence : 0.0;

      final category = _inferCategory(rawLabels);
      final style = _inferStyle(rawLabels);
      final name = _inferName(rawLabels, category);

      // Save to history
      await DatabaseHelper.instance.saveAiLabel({
        'imagePath': imagePath,
        'rawLabels': rawLabels.join(','),
        'suggestedCategory': category,
        'suggestedStyle': style,
      });

      return AiLabelResult(
        suggestedCategory: category,
        suggestedStyle: style,
        suggestedName: name,
        rawLabels: rawLabels,
        confidence: confidence,
      );
    } catch (e) {
      return null;
    }
  }

  static String _inferCategory(List<String> labels) {
    // Map ML Kit labels to wardrobe categories
    final labelStr = labels.join(' ');
    if (_containsAny(labelStr, ['shoe', 'boot', 'sneaker', 'sandal', 'footwear', 'heel'])) {
      return 'Giày';
    }
    if (_containsAny(labelStr, ['dress', 'skirt', 'gown', 'sundress', 'mini'])) {
      return 'Váy / Đầm';
    }
    if (_containsAny(labelStr, ['jacket', 'coat', 'blazer', 'hoodie', 'sweater', 'cardigan'])) {
      return 'Áo khoác';
    }
    if (_containsAny(labelStr, ['shirt', 'top', 't-shirt', 'blouse', 'polo', 'sleeve'])) {
      return 'Áo';
    }
    if (_containsAny(labelStr, ['pant', 'trouser', 'jean', 'shorts', 'legging', 'denim'])) {
      return 'Quần';
    }
    if (_containsAny(labelStr, ['bag', 'belt', 'hat', 'cap', 'watch', 'accessory',
        'sunglasses', 'scarf', 'necklace', 'bracelet'])) {
      return 'Phụ kiện';
    }
    return 'Áo'; // default
  }

  static String? _inferStyle(List<String> labels) {
    final labelStr = labels.join(' ');
    if (_containsAny(labelStr, ['sport', 'athletic', 'gym', 'workout', 'training'])) {
      return 'Thể thao';
    }
    if (_containsAny(labelStr, ['formal', 'suit', 'office', 'business', 'professional'])) {
      return 'Công sở';
    }
    if (_containsAny(labelStr, ['casual', 'everyday', 'basic', 'simple'])) {
      return 'Casual';
    }
    if (_containsAny(labelStr, ['street', 'urban', 'hoodie', 'streetwear', 'hip'])) {
      return 'Streetwear';
    }
    if (_containsAny(labelStr, ['vintage', 'retro', 'classic', 'antique'])) {
      return 'Vintage';
    }
    return null;
  }

  static String? _inferName(List<String> labels, String category) {
    final adjectives = <String>[];
    if (labels.any((l) => l.contains('white'))) adjectives.add('Trắng');
    if (labels.any((l) => l.contains('black'))) adjectives.add('Đen');
    if (labels.any((l) => l.contains('blue') || l.contains('denim'))) adjectives.add('Xanh');
    if (labels.any((l) => l.contains('red'))) adjectives.add('Đỏ');
    if (labels.any((l) => l.contains('pattern') || l.contains('stripe'))) adjectives.add('Kẻ');
    if (labels.any((l) => l.contains('floral') || l.contains('flower'))) adjectives.add('Hoa');
    if (labels.any((l) => l.contains('oversize'))) adjectives.add('Oversized');

    final prefix = adjectives.isNotEmpty ? '${adjectives.first} ' : '';
    return '$prefix$category';
  }

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  static void dispose() {
    _labeler?.close();
    _labeler = null;
  }
}