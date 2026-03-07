import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart'; // Đảm bảo đường dẫn này khớp với file của bạn

void main() {
  // Đảm bảo các dịch vụ hệ thống của Flutter đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // Khóa hướng màn hình luôn là chiều dọc (tùy chọn nhưng nên có cho app fashion)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Tên dự án của bạn
      title: 'FashionManager',
      
      // Tắt biểu nhãn "Debug" ở góc màn hình
      debugShowCheckedModeBanner: false,

      // Thiết lập Theme (Phong cách chủ đạo: Minimalist - Tối giản)
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          secondary: Colors.grey[800]!,
        ),
        
        // Cấu hình AppBar chung cho toàn App
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.black,
          ),
        ),

        // Cấu hình font chữ mặc định
        fontFamily: 'Roboto', // Bạn có thể đổi sang font khác nếu đã cài đặt
      ),

      // Màn hình khởi đầu là Thanh điều hướng (có 4 mục)
      home: const MainNavigationScreen(),
    );
  }
}