// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ZandoInventoryApp());
}

class ZandoInventoryApp extends StatelessWidget {
  const ZandoInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zando Inventory',
      debugShowCheckedModeBanner: false, // Removes the red debug banner
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const LoginScreen(),
    );
  }
}
