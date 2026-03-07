import 'package:flutter/material.dart';
import 'wardrobe_screen.dart'; // Đảm bảo bạn đã có file wardrobe_screen.dart trong cùng thư mục

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // Chỉ định vị trí tab mặc định: 0: Trang chủ, 1: Tủ đồ, 2: Lịch, 3: AI
  int _selectedIndex = 1; 

  // Danh sách các màn hình tương ứng với từng tab
  final List<Widget> _pages = [
    const Center(child: Text("Màn hình Trang chủ")),
    WardrobeScreen(), // Đây là màn hình chính của Module 1
    const Center(child: Text("Màn hình Lịch trình")),
    const Center(child: Text("Màn hình AI Gợi ý")),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack giúp giữ nguyên trạng thái của các tab khi chuyển đổi (không bị load lại từ đầu)
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Hiển thị tất cả label
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom_outlined),
            activeIcon: Icon(Icons.checkroom),
            label: 'Tủ đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Lịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}