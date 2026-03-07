// lib/main_screen.dart
import 'package:flutter/material.dart';
import '../screens/wardrobe_screen.dart'; // Màn hình tủ đồ

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Mặc định mở mục Tủ đồ (index 1)

  final List<Widget> _pages = [
    Center(child: Text("Trang chủ (Trống)")),
    WardrobeScreen(), // Mục Tủ đồ
    Center(child: Text("Lịch (Trống)")),
    Center(child: Text("AI Gợi ý (Trống)")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: "Tủ đồ"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Lịch"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AI"),
        ],
      ),
    );
  }
}