import 'package:flutter/material.dart';  // 添加这个基础导入
import 'package:flutter_localizations/flutter_localizations.dart';

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
      // 添加本地化配置
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文简体
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'CN'), // 设置默认语言为中文
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
