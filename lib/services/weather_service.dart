import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class WeatherData {
  final String city;
  final double tempC;
  final double feelsLike;
  final int humidity;
  final String condition;
  final String icon;
  final double windKph;
  final bool fromCache;

  const WeatherData({
    required this.city,
    required this.tempC,
    required this.feelsLike,
    required this.humidity,
    required this.condition,
    required this.icon,
    required this.windKph,
    this.fromCache = false,
  });

  factory WeatherData.fromMap(Map<String, dynamic> m, {bool fromCache = false}) =>
      WeatherData(
        city: m['city'] as String? ?? '',
        tempC: (m['tempC'] as num?)?.toDouble() ?? 0,
        feelsLike: (m['feelsLike'] as num?)?.toDouble() ?? 0,
        humidity: (m['humidity'] as num?)?.toInt() ?? 0,
        condition: m['condition'] as String? ?? '',
        icon: m['icon'] as String? ?? '01d',
        windKph: (m['windKph'] as num?)?.toDouble() ?? 0,
        fromCache: fromCache,
      );

  Map<String, dynamic> toMap() => {
        'city': city,
        'tempC': tempC,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'condition': condition,
        'icon': icon,
        'windKph': windKph,
      };

  String get weatherEmoji {
    final cond = condition.toLowerCase();
    if (cond.contains('thunder')) return '⛈️';
    if (cond.contains('drizzle') || cond.contains('rain')) return '🌧️';
    if (cond.contains('snow')) return '❄️';
    if (cond.contains('mist') || cond.contains('fog')) return '🌫️';
    if (cond.contains('cloud')) return '☁️';
    return '☀️';
  }

  String get dressAdvice {
    if (tempC < 10) return 'Mặc thêm áo khoác dày, khăn quàng và găng tay!';
    if (tempC < 18) return 'Nên mặc áo khoác nhẹ hoặc áo len.';
    if (tempC < 25) return 'Thời tiết lý tưởng, mặc thoải mái nhé!';
    if (tempC < 32) return 'Trời ấm, chọn đồ mỏng nhẹ thoáng mát.';
    return 'Rất nóng! Ưu tiên đồ cotton, màu sáng, thoáng khí.';
  }
}

class WeatherService {
  // Using OpenWeatherMap free tier — replace with your actual API key
  static const _apiKey = 'YOUR_OPENWEATHER_API_KEY';
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5';

  static Future<WeatherData?> fetchWeather({
    String city = 'Ho Chi Minh City',
    bool forceRefresh = false,
  }) async {
    final db = DatabaseHelper.instance;

    // Try cache first
    if (!forceRefresh) {
      final cached = await db.getWeatherCache(maxAgeMinutes: 30);
      if (cached != null) {
        return WeatherData.fromMap(cached, fromCache: true);
      }
    }

    // Try API
    try {
      final uri = Uri.parse(
          '$_baseUrl/weather?q=$city&units=metric&lang=vi&appid=$_apiKey');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = WeatherData(
          city: (json['name'] as String?) ?? city,
          tempC: (json['main']?['temp'] as num?)?.toDouble() ?? 0,
          feelsLike: (json['main']?['feels_like'] as num?)?.toDouble() ?? 0,
          humidity: (json['main']?['humidity'] as num?)?.toInt() ?? 0,
          condition: (json['weather']?[0]?['description'] as String?) ?? '',
          icon: (json['weather']?[0]?['icon'] as String?) ?? '01d',
          windKph: ((json['wind']?['speed'] as num?)?.toDouble() ?? 0) * 3.6,
        );
        await db.saveWeatherCache(data.toMap());
        return data;
      }
    } catch (_) {}

    // Fallback: stale cache (no age check)
    final stale = await db.getWeatherCache(maxAgeMinutes: 99999);
    if (stale != null) return WeatherData.fromMap(stale, fromCache: true);

    // Mock data for demo (when no API key)
    return _mockWeather(city);
  }

  static WeatherData _mockWeather(String city) => WeatherData(
        city: city,
        tempC: 31,
        feelsLike: 34,
        humidity: 78,
        condition: 'Nắng, một phần mây',
        icon: '02d',
        windKph: 12,
      );
}