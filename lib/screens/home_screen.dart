import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/weather_service.dart';
import '../services/news_service.dart';
import '../services/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  WeatherData? _weather;
  List<NewsArticle> _news = [];
  List<ShoppingItem> _shopping = [];
  List<Map<String, dynamic>> _recommendedOutfits = [];
  Map<String, dynamic> _stats = {};

  bool _isLoadingWeather = true;
  bool _isLoadingContent = true;
  bool _isLoadingRecs = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final PageController _newsPageController = PageController(viewportFraction: 0.92);
  int _currentNewsPage = 0;

  // Warm cream-based palette
  static const _bg = Color(0xFFFAF8F5);
  static const _card = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF1A1A1A);
  static const _inkLight = Color(0xFF8A8A8A);
  static const _accent = Color(0xFFD4A853);   // warm gold
  static const _accentSoft = Color(0xFFFFF4E0);
  static const _surface = Color(0xFFF2EFE9);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _loadAll();
  }

  @override
  void dispose() {
    _animController.dispose();
    _newsPageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadWeather(), _loadContent(), _loadStats()]);
    if (mounted) _animController.forward();
  }

  Future<void> _loadWeather() async {
    final w = await WeatherService.fetchWeather();
    if (!mounted) return;
    setState(() { _weather = w; _isLoadingWeather = false; });
    if (w != null) _loadRecs(w.tempC);
  }

  Future<void> _loadRecs(double tempC) async {
    final outfits = await _db.getRecommendedOutfits(tempC: tempC);
    if (!mounted) return;
    setState(() { _recommendedOutfits = outfits; _isLoadingRecs = false; });
  }

  Future<void> _loadContent() async {
    final results = await Future.wait([
      NewsService.fetchFashionNews(),
      ShoppingService.fetchShoppingItems(),
    ]);
    if (!mounted) return;
    setState(() {
      _news = results[0] as List<NewsArticle>;
      _shopping = results[1] as List<ShoppingItem>;
      _isLoadingContent = false;
    });
  }

  Future<void> _loadStats() async {
    final s = await _db.getWardrobeStats();
    if (mounted) setState(() => _stats = s);
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoadingWeather = true;
      _isLoadingContent = true;
      _isLoadingRecs = true;
    });
    _animController.reset();
    await _loadAll();
  }

  // ── URL Launcher ──────────────────────────────────────────────────────────

  Future<void> _openUrl(String url) async {
    if (url.isEmpty || !url.startsWith('http')) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể mở: $url'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _ink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (_) {}
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: _ink,
          backgroundColor: _card,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildWeatherCard(),
                          const SizedBox(height: 12),
                          _buildDressAdvice(),
                          const SizedBox(height: 24),
                          _buildStatsRow(),
                          const SizedBox(height: 28),
                          _buildSectionHeader('GỢI Ý HÔM NAY',
                              badge: _weather != null
                                  ? '${_weather!.tempC.toStringAsFixed(0)}°C'
                                  : null),
                          const SizedBox(height: 14),
                          _buildRecommendations(),
                          const SizedBox(height: 32),
                          _buildSectionHeader('TIN TỨC THỜI TRANG'),
                          const SizedBox(height: 14),
                          _buildNewsSlider(),
                          const SizedBox(height: 32),
                          _buildSectionHeader('GỢI Ý MUA SẮM'),
                          const SizedBox(height: 14),
                          _buildShoppingRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Chào buổi sáng' : hour < 17 ? 'Buổi chiều vui vẻ' : 'Chào buổi tối';
    final emoji = hour < 12 ? '🌤' : hour < 17 ? '☀️' : '🌙';

    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      floating: false,
      backgroundColor: _bg,
      surfaceTintColor: _bg,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Row(
          children: [
            Text(
              'SmartWardrobe',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink.withOpacity(0.9),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        background: Container(
          color: _bg,
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting $emoji',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateVi(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _inkLight,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _refresh,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: _ink, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Weather Card ─────────────────────────────────────────────────────────

  Widget _buildWeatherCard() {
    if (_isLoadingWeather) return _shimmer(height: 160, mx: 16);
    if (_weather == null) return const SizedBox.shrink();
    final w = _weather!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: temp + condition
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Text(w.city,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      if (w.fromCache) ...[
                        const SizedBox(width: 8),
                        _pill('Cache', Colors.white12, Colors.white38),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${w.tempC.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w200,
                          height: 1,
                          letterSpacing: -2,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('C',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 22)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.condition,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Right: emoji + stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(w.weatherEmoji,
                    style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 16),
                _wStat(Icons.water_drop_outlined, '${w.humidity}%'),
                const SizedBox(height: 6),
                _wStat(Icons.air, '${w.windKph.toStringAsFixed(0)} km/h'),
                const SizedBox(height: 6),
                _wStat(Icons.thermostat_outlined,
                    'Cảm ${w.feelsLike.toStringAsFixed(0)}°'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wStat(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 11),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );

  // ─── Dress Advice ─────────────────────────────────────────────────────────

  Widget _buildDressAdvice() {
    if (_weather == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tips_and_updates_outlined,
                  color: _accent, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _weather!.dressAdvice,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    if (_stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statTile('${_stats['totalItems'] ?? 0}', 'Trang phục',
              '👗', const Color(0xFFE8F4FD)),
          const SizedBox(width: 10),
          _statTile('${_stats['totalOutfits'] ?? 0}', 'Bộ đồ',
              '✨', const Color(0xFFF0F0FF)),
          const SizedBox(width: 10),
          _statTile('${_stats['upcomingSchedules'] ?? 0}', 'Sắp tới',
              '📅', const Color(0xFFEDF7ED)),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, String emoji, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: _inkLight,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              color: _ink,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            _pill(badge, _ink, Colors.white),
          ],
        ],
      ),
    );
  }

  // ─── Recommendations ──────────────────────────────────────────────────────

  Widget _buildRecommendations() {
    if (_isLoadingRecs) return _hShimmer();
    if (_recommendedOutfits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chưa có bộ đồ nào',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Tạo bộ đồ để nhận gợi ý phù hợp thời tiết!',
                        style: TextStyle(fontSize: 12, color: _inkLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recommendedOutfits.length,
        itemBuilder: (ctx, i) => _outfitCard(_recommendedOutfits[i]),
      ),
    );
  }

  Widget _outfitCard(Map<String, dynamic> outfit) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getItemsOfOutfit(outfit['id'] as int),
      builder: (ctx, snap) {
        final items = snap.data ?? [];
        return Container(
          width: 155,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
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
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: items.isEmpty
                      ? Container(
                          color: _surface,
                          child: const Center(
                            child: Text('✨', style: TextStyle(fontSize: 32)),
                          ),
                        )
                      : _miniPreview(items),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit['name'] as String? ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${outfit['itemCount'] ?? 0} món đồ',
                      style: const TextStyle(
                          fontSize: 11, color: _inkLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniPreview(List<Map<String, dynamic>> items) {
    if (items.length == 1) {
      final f = File(items.first['image_path'] as String? ?? '');
      return f.existsSync()
          ? Image.file(f, fit: BoxFit.cover)
          : Container(color: _surface);
    }
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: items.take(4).map((item) {
        final f = File(item['image_path'] as String? ?? '');
        return f.existsSync()
            ? Image.file(f, fit: BoxFit.cover)
            : Container(color: _surface);
      }).toList(),
    );
  }

  // ─── News Slider ──────────────────────────────────────────────────────────

  Widget _buildNewsSlider() {
    if (_isLoadingContent) return _shimmer(height: 200, mx: 16);
    if (_news.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _newsPageController,
            onPageChanged: (i) => setState(() => _currentNewsPage = i),
            itemCount: _news.length,
            itemBuilder: (ctx, i) => _newsCard(_news[i]),
          ),
        ),
        const SizedBox(height: 14),
        // Indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _news.length.clamp(0, 6),
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentNewsPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentNewsPage == i ? _ink : _surface,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newsCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openUrl(article.url),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          article.source,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (article.publishedAt != null)
                        Text(
                          _timeAgo(article.publishedAt!),
                          style: const TextStyle(
                              fontSize: 11, color: _inkLight),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _ink,
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.description,
                    style: const TextStyle(
                        fontSize: 12, color: _inkLight, height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Tap indicator (bottom right)
            if (article.hasRealUrl)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Đọc thêm',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new,
                          color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Shopping Row ─────────────────────────────────────────────────────────

  Widget _buildShoppingRow() {
    if (_isLoadingContent) return _hShimmer();
    if (_shopping.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _shopping.length,
        itemBuilder: (ctx, i) => _shoppingCard(_shopping[i], i),
      ),
    );
  }

  static const _cardColors = [
    Color(0xFFFFF0E6), Color(0xFFE8F4FD), Color(0xFFF0F4E8),
    Color(0xFFFDE8F4), Color(0xFFF4F0FD), Color(0xFFFDF4E8),
    Color(0xFFE8FDF4), Color(0xFFFDF8E8),
  ];

  Widget _shoppingCard(ShoppingItem item, int index) {
    final bg = _cardColors[index % _cardColors.length];
    return GestureDetector(
      onTap: () => _openUrl(item.url),
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Container(
              height: 112,
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  if (item.imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      child: Image.network(
                        item.imageUrl!,
                        width: double.infinity,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _shoppingPlaceholder(bg, item),
                      ),
                    )
                  else
                    _shoppingPlaceholder(bg, item),
                  // Open link badge
                  if (item.hasRealUrl)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.open_in_new,
                            size: 13, color: _ink),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.brand != null) ...[
                    Text(
                      item.brand!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _inkLight,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _ink,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.price,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shoppingPlaceholder(Color bg, ShoppingItem item) {
    final icons = {
      'Áo': '👕', 'Quần': '👖', 'Váy': '👗',
      'Giày': '👟', 'Phụ kiện': '👜'
    };
    final em = icons[item.category] ?? '🛍️';
    return Container(
      width: double.infinity,
      height: 112,
      color: bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(em, style: const TextStyle(fontSize: 30)),
          if (item.brand != null) ...[
            const SizedBox(height: 4),
            Text(
              item.brand!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Shimmer loaders ──────────────────────────────────────────────────────

  Widget _shimmer({required double height, required double mx}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mx),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }

  Widget _hShimmer() {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (_, i) => Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _pill(String label, Color bg, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );

  String _formatDateVi() {
    final now = DateTime.now();
    const weekdays = [
      'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
      'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'
    ];
    const months = [
      'tháng 1', 'tháng 2', 'tháng 3', 'tháng 4',
      'tháng 5', 'tháng 6', 'tháng 7', 'tháng 8',
      'tháng 9', 'tháng 10', 'tháng 11', 'tháng 12'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
      if (diff.inHours < 24) return '${diff.inHours}h trước';
      return '${diff.inDays}d trước';
    } catch (_) {
      return '';
    }
  }
}