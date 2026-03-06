// lib/screens/sale_dashboard.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'login_screen.dart';

class SaleDashboard extends StatefulWidget {
  const SaleDashboard({super.key});

  @override
  State<SaleDashboard> createState() => _SaleDashboardState();
}

class _SaleDashboardState extends State<SaleDashboard> {
  List inventory = [];
  bool isLoading = true;
  bool isKhmer = false;

  String tr(String en, String km) => isKhmer ? km : en;

  Future<void> fetchInventory() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        // 🚀 CHANGED TO CLOUD URL
        Uri.parse('https://zando-inventory-backend.onrender.com/api/inventory'),
      );
      if (response.statusCode == 200) {
        setState(() {
          inventory = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> sellItem(String skuCode) async {
    try {
      final response = await http.post(
        // 🚀 CHANGED TO CLOUD URL
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/sell',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sku_code': skuCode, 'quantity': 1}),
      );
      if (context.mounted && response.statusCode == 200) fetchInventory();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> receiveItem(String skuCode) async {
    try {
      final response = await http.post(
        // 🚀 CHANGED TO CLOUD URL
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/receive',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sku_code': skuCode, 'quantity': 100}),
      );
      if (context.mounted && response.statusCode == 200) fetchInventory();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void showManualEntryDialog() {
    TextEditingController skuController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Manual Scan', 'ស្កេនដោយដៃ')),
        content: TextField(
          controller: skuController,
          decoration: InputDecoration(labelText: tr('Enter SKU', 'បញ្ចូល SKU')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel', 'បោះបង់')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (skuController.text.isNotEmpty) {
                receiveItem(skuController.text.trim());
              }
            },
            child: Text(tr('Submit', 'បញ្ជូន')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          tr('Zando POS & Receiving', 'ប្រព័ន្ធលក់ និងទទួលស្តុក Zando'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => setState(() => isKhmer = !isKhmer),
            child: Text(
              isKhmer ? 'EN' : 'ខ្មែរ',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.checkroom,
                      color: Colors.blueGrey,
                      size: 32,
                    ),
                    title: Text(
                      item['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'SKU: ${item['sku']} | Size: ${item['size']}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item['stock']} ${tr('Units', 'ឯកតា')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => sellItem(item['sku']),
                          child: Text(
                            tr('Deduct 1', 'ដក ១'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "mBtn",
            onPressed: showManualEntryDialog,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.keyboard),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "sBtn",
            onPressed: () async {
              var res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SimpleBarcodeScannerPage(),
                ),
              );
              if (res is String && res != '-1') receiveItem(res);
            },
            backgroundColor: const Color(0xFF0F172A),
            icon: const Icon(Icons.barcode_reader, color: Colors.white),
            label: Text(
              tr('Scan', 'ស្កេន'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
