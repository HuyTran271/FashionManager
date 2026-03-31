import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

// ─── Models ───────────────────────────────────────────────────────────────

class NewsArticle {
  final String title;
  final String description;
  final String url;
  final String? imageUrl;
  final String source;
  final String? publishedAt;

  const NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    this.imageUrl,
    required this.source,
    this.publishedAt,
  });

  factory NewsArticle.fromMap(Map<String, dynamic> m) => NewsArticle(
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        url: m['url'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        source: m['source'] as String? ?? '',
        publishedAt: m['publishedAt'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'url': url,
        'imageUrl': imageUrl,
        'source': source,
        'publishedAt': publishedAt,
      };

  bool get hasRealUrl => url.isNotEmpty && url.startsWith('http');
}

class ShoppingItem {
  final String title;
  final String price;
  final String? imageUrl;
  final String url;
  final String? brand;
  final String? category;

  const ShoppingItem({
    required this.title,
    required this.price,
    this.imageUrl,
    required this.url,
    this.brand,
    this.category,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> m) => ShoppingItem(
        title: m['title'] as String? ?? '',
        price: m['price'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        url: m['url'] as String? ?? '',
        brand: m['brand'] as String?,
        category: m['category'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'price': price,
        'imageUrl': imageUrl,
        'url': url,
        'brand': brand,
        'category': category,
      };

  bool get hasRealUrl => url.isNotEmpty && url.startsWith('http');
}

// ─── News Service ─────────────────────────────────────────────────────────

class NewsService {
  static const _newsApiKey = 'YOUR_NEWS_API_KEY';
  static const _gNewsToken = '';

  static Future<List<NewsArticle>> fetchFashionNews({
    bool forceRefresh = false,
  }) async {
    final db = DatabaseHelper.instance;

    if (!forceRefresh) {
      final cached = await db.getNewsCache(maxAgeMinutes: 60);
      if (cached.isNotEmpty) {
        print("💡 Lấy dữ liệu từ Cache thành công.");
        return cached.map(NewsArticle.fromMap).toList();
      }
    }

    // Thử NewsAPI
    if (_gNewsToken.isNotEmpty && !_gNewsToken.contains('YOUR_GNEWS')) {
      final articles = await _fetchFromGNews();
      if (articles.isNotEmpty) {
        print("✅ Lấy dữ liệu từ GNews thành công.");
        await db.saveNewsCache(articles.map((a) => a.toMap()).toList());
        return articles;
      }
    }

    // 3. THỬ NEWSAPI (Nếu GNews thất bại)
    if (_newsApiKey != 'YOUR_NEWS_API_KEY') {
      final articles = await _fetchFromNewsApi();
      if (articles.isNotEmpty) {
        print("✅ Lấy dữ liệu từ NewsAPI thành công.");
        await db.saveNewsCache(articles.map((a) => a.toMap()).toList());
        return articles;
      }
    }

    // 4. FALLBACK: Nếu API lỗi, lấy cache cũ hoặc cuối cùng mới hiện MOCK
    final stale = await db.getNewsCache(maxAgeMinutes: 99999);
    if (stale.isNotEmpty) return stale.map(NewsArticle.fromMap).toList();
    
    print("⚠️ Tất cả API đều lỗi, hiển thị Mock Data.");
    return _mockNewsWithRealUrls();
  }

  static Future<List<NewsArticle>> _fetchFromNewsApi() async {
    try {
      final uri = Uri.parse(
          'https://newsapi.org/v2/everything'
          '?q=fashion+style+clothing'
          '&language=en&sortBy=publishedAt&pageSize=8'
          '&apiKey=$_newsApiKey');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return ((json['articles'] as List?) ?? [])
            .where((a) => a['url'] != null && a['title'] != null)
            .map((a) => NewsArticle(
                  title: a['title'] ?? '',
                  description: a['description'] ?? '',
                  url: a['url'] ?? '',
                  imageUrl: a['urlToImage'],
                  source: a['source']?['name'] ?? 'NewsAPI',
                  publishedAt: a['publishedAt'],
                ))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<NewsArticle>> _fetchFromGNews() async {
    try {
      final uri = Uri.parse(
          'https://gnews.io/api/v4/search'
          '?q=fashion+style&lang=en&max=8'
          '&token=$_gNewsToken');

      print("🌐 Đang gọi GNews: $uri");
      
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final List? articlesJson = json['articles'];
        
        if (articlesJson == null) return [];

        return articlesJson.map((a) => NewsArticle(
                  title: a['title'] ?? '',
                  description: a['description'] ?? '',
                  url: a['url'] ?? '',
                  imageUrl: a['image'], // GNews dùng 'image'
                  source: a['source']?['name'] ?? 'GNews',
                  publishedAt: a['publishedAt'],
                )).toList();
      } else {
        // IN LỖI ĐỂ DEBUG
        print("❌ Lỗi GNews (${res.statusCode}): ${res.body}");
      }
    } catch (e) {
      print("❌ Lỗi kết nối GNews: $e");
    }
    return [];
  }

  static List<NewsArticle> _mockNewsWithRealUrls() => [
        NewsArticle(
          title: 'Xu hướng thời trang Thu - Đông 2025: Tông màu trái đất lên ngôi',
          description:
              'Gam màu đất, vải linen tự nhiên và silhouette oversized cổ điển '
              'đang dẫn đầu xu hướng thời trang mùa Thu - Đông năm nay.',
          url: 'https://elle.vn/thoi-trang',
          source: 'Elle Vietnam',
          publishedAt: DateTime.now().toIso8601String(),
        ),
        NewsArticle(
          title: 'Cách phối đồ Minimalist đi làm: Đẹp và chuyên nghiệp',
          description:
              'Tối giản không có nghĩa là nhàm chán. Chất liệu và silhouette '
              'chính là ngôn ngữ thời trang của bạn.',
          url: 'https://dep.com.vn/thoi-trang',
          source: 'Đẹp Magazine',
          publishedAt: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        ),
        NewsArticle(
          title: 'Streetwear Việt Nam: Làn sóng thương hiệu nội địa bứt phá',
          description:
              'Các thương hiệu streetwear nội địa khẳng định vị thế với '
              'thiết kế độc đáo mang đậm văn hóa Việt.',
          url: 'https://vogue.com/fashion',
          source: 'Vogue',
          publishedAt: DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        ),
        NewsArticle(
          title: 'Sustainable Fashion: Mua ít, chọn kỹ, mặc bền',
          description:
              'Thời trang bền vững không chỉ là xu hướng mà còn là triết lý '
              'sống được giới trẻ Việt Nam đón nhận.',
          url: 'https://harpersbazaar.com/fashion',
          source: "Harper's Bazaar",
          publishedAt: DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(),
        ),
        NewsArticle(
          title: 'Capsule Wardrobe 2025: 15 món đồ tạo 100 outfit khác nhau',
          description:
              'Xây dựng tủ quần áo tối giản thông minh giúp bạn tiết kiệm '
              'thời gian và tiền bạc mỗi ngày.',
          url: 'https://whowhatwear.com',
          source: 'Who What Wear',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        ),
      ];
}

// ─── Shopping Service ─────────────────────────────────────────────────────

class ShoppingService {
  static Future<List<ShoppingItem>> fetchShoppingItems({
    String query = 'thời trang nữ',
    bool forceRefresh = false,
  }) async {
    final db = DatabaseHelper.instance;

    if (!forceRefresh) {
      final cached = await db.getShoppingCache();
      if (cached.isNotEmpty) return cached.map(ShoppingItem.fromMap).toList();
    }

    // Thử Tiki API thật (không cần key)
    final tikiItems = await _fetchFromTiki(query);
    if (tikiItems.isNotEmpty) {
      await db.saveShoppingCache(tikiItems.map((i) => i.toMap()).toList());
      return tikiItems;
    }

    // Fallback mock với URL thật
    final mock = _mockShoppingWithRealUrls();
    await db.saveShoppingCache(mock.map((i) => i.toMap()).toList());
    return mock;
  }

  static Future<List<ShoppingItem>> _fetchFromTiki(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
          'https://tiki.vn/api/v2/products'
          '?q=$encoded&limit=10&sort=popular');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (compatible)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (json['data'] as List?) ?? [];
        if (data.isEmpty) return [];
        return data.take(10).map((p) {
          final slug = p['url_path'] as String? ?? '';
          return ShoppingItem(
            title: p['name'] as String? ?? '',
            price: _formatVnd(p['price']),
            imageUrl: p['thumbnail_url'] as String?,
            url: slug.isNotEmpty ? 'https://tiki.vn/$slug' : 'https://tiki.vn/search?q=$encoded',
            brand: p['brand_name'] as String?,
            category: 'Thời trang',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static String _formatVnd(dynamic price) {
    if (price == null) return '';
    final n = price is num ? price.toInt() : int.tryParse(price.toString()) ?? 0;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()}₫';
  }

  static List<ShoppingItem> _mockShoppingWithRealUrls() => [
        ShoppingItem(
          title: 'Áo sơ mi trắng oversize basic unisex',
          price: '299.000₫',
          url: 'https://tiki.vn/search?q=ao+so+mi+trang+oversize',
          brand: 'Canifa',
          category: 'Áo',
        ),
        ShoppingItem(
          title: 'Quần jeans ống suông vintage wash',
          price: '450.000₫',
          url: 'https://tiki.vn/search?q=quan+jeans+ong+suong',
          brand: 'Routine',
          category: 'Quần',
        ),
        ShoppingItem(
          title: 'Blazer kẻ caro công sở nữ',
          price: '680.000₫',
          url: 'https://shopee.vn/search?keyword=blazer+ke+caro',
          brand: 'Elise',
          category: 'Áo khoác',
        ),
        ShoppingItem(
          title: 'Váy midi hoa nhí tay bồng',
          price: '380.000₫',
          url: 'https://shopee.vn/search?keyword=vay+midi+hoa+nhi',
          brand: 'Ivy Moda',
          category: 'Váy',
        ),
        ShoppingItem(
          title: 'Áo thun cotton ribbed basic',
          price: '179.000₫',
          url: 'https://tiki.vn/search?q=ao+thun+cotton+ribbed',
          brand: 'GenZ',
          category: 'Áo',
        ),
        ShoppingItem(
          title: 'Sneaker trắng Biti\'s Hunter Street',
          price: '699.000₫',
          url: 'https://tiki.vn/search?q=bitis+hunter+street',
          brand: "Biti's",
          category: 'Giày',
        ),
        ShoppingItem(
          title: 'Túi tote canvas thời trang',
          price: '149.000₫',
          url: 'https://shopee.vn/search?keyword=tui+tote+canvas',
          brand: 'Local Brand',
          category: 'Phụ kiện',
        ),
        ShoppingItem(
          title: 'Quần short linen mùa hè',
          price: '220.000₫',
          url: 'https://tiki.vn/search?q=quan+short+linen',
          brand: 'Routine',
          category: 'Quần',
        ),
      ];
}