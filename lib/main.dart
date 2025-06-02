import 'package:flutter/material.dart';

// 引入我们刚刚创建的 dashboard_screen.dart
import 'screens/dashboard_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '生产统计助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 将 home 从 PlaceholderHomeScreen 修改为 DashboardScreen
      home: const DashboardScreen(), 
    );
  }
}

// PlaceholderHomeScreen 不再需要，可以删除
/*
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生产统计助手'),
      ),
      body: const Center(
        child: Text('仪表盘页面即将呈现...'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 实现快捷录入功能
        },
        tooltip: '快捷录入',
        child: const Icon(Icons.add),
      ),
    );
  }
}
*/
