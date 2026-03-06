// lib/screens/dashboard_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'prediction_screen.dart'; // 🚀 NEW: Import your Machine Learning screen!

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List inventory = [];
  bool isLoading = true;
  bool isKhmer = false;

  String tr(String en, String km) {
    return isKhmer ? km : en;
  }

  Future<void> fetchInventory() async {
    setState(() => isLoading = true);
    // 🚀 CHANGED: Now pulling live cloud data!
    final url = Uri.parse(
      'https://zando-inventory-backend.onrender.com/api/inventory',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          inventory = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> sellItem(String skuCode) async {
    try {
      final response = await http.post(
        // 🚀 CHANGED: Cloud URL
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/sell',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sku_code': skuCode, 'quantity': 1}),
      );

      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  '🛒 Item Sold! -1 from stock.',
                  '🛒 បានលក់! ដក ១ ចេញពីស្តុក',
                ),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          fetchInventory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('❌ System Rejected: ', '❌ ប្រព័ន្ធបដិសេធ: ') +
                    '${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🛑 Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> receiveItem(String skuCode) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('⏳ Processing SKU...', '⏳ កំពុងដំណើរការ SKU...')),
        backgroundColor: Colors.blueGrey,
      ),
    );
    try {
      final response = await http.post(
        // 🚀 CHANGED: Cloud URL
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/receive',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sku_code': skuCode, 'quantity': 100}),
      );
      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  '✅ Inventory Updated: +100 units',
                  '✅ បានធ្វើបច្ចុប្បន្នភាពស្តុក: +100 ឯកតា',
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
          fetchInventory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('❌ Error: Barcode invalid.', '❌ កំហុស៖ បាកូដមិនត្រឹមត្រូវ។'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🛑 Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> autoOrderStock() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            '⚙️ Initializing AI Restock Protocol...',
            '⚙️ កំពុងចាប់ផ្តើមប្រព័ន្ធបញ្ជាទិញ AI...',
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
    try {
      final response = await http.post(
        // 🚀 CHANGED: Cloud URL
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/auto-order',
        ),
      );
      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  '📦 AI Auto-Order Executed Successfully!',
                  '📦 ការបញ្ជាទិញស្តុកដោយ AI ជោគជ័យ!',
                ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          fetchInventory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('❌ AI Protocol Failed.', '❌ ប្រព័ន្ធ AI បរាជ័យ។'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🛑 Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void showManualEntryDialog() {
    TextEditingController skuController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            tr('Manual Data Entry', 'បញ្ចូលទិន្នន័យដោយដៃ'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: skuController,
            decoration: InputDecoration(
              labelText: tr('Enter Target SKU', 'បញ្ចូលលេខកូដ SKU'),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('Cancel', 'បោះបង់'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (skuController.text.isNotEmpty) {
                  receiveItem(skuController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
              ),
              child: Text(
                tr('Execute', 'ដំណើរការ'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Color getStockColor(int stock) {
    if (stock <= 0) return const Color(0xFFDC2626); // Professional Red
    if (stock < 20) return const Color(0xFFD97706); // Professional Amber
    return const Color(0xFF059669); // Professional Green
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalStock = 0;
    int highRiskCount = 0;

    for (var item in inventory) {
      totalStock += (item['stock'] as int);
      if (item['is_high_risk'] == true) {
        highRiskCount++;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          tr('Zando Enterprise Systems', 'ប្រព័ន្ធគ្រប់គ្រង Zando'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => setState(() => isKhmer = !isKhmer),
            child: Text(
              isKhmer ? 'EN' : 'ខ្មែរ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: fetchInventory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : Column(
              children: [
                // Executive Summary Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: tr('Global Inventory', 'ស្តុកសរុប'),
                          value: '$totalStock',
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          title: tr('System Alerts', 'ការព្រមានធ្ងន់ធ្ងរ'),
                          value: '$highRiskCount',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),

                // AI Action Center
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: autoOrderStock,
                      icon: const Icon(Icons.memory, color: Colors.white),
                      label: Text(
                        tr(
                          'Execute AI Predictive Restock',
                          'ដំណើរការប្រព័ន្ធបញ្ជាទិញដោយ AI',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

                // Analytical Data List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: inventory.length,
                    itemBuilder: (context, index) {
                      final item = inventory[index];
                      final bool isHighRisk = item['is_high_risk'] ?? false;
                      final int stock = item['stock'] ?? 0;
                      final String skuCode = item['sku'] ?? 'N/A';

                      // 🚨 NOTE: Assuming your database has an 'id' column for the product!
                      final int productId = item['id'] ?? 1;

                      // 🚀 NEW: GestureDetector makes the whole card clickable!
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PredictionScreen(
                                productId: productId,
                                productName: item['name'] ?? 'Unknown',
                                currentStock: stock,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isHighRisk
                                  ? const Color(0xFFDC2626).withOpacity(0.3)
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.category_outlined,
                                    color: Color(0xFF64748B),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Unknown Item',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: $skuCode  |  Size: ${item['size'] ?? 'N/A'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontFamily: 'Courier',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.insights,
                                            size: 14,
                                            color: isHighRisk
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF4F46E5),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${tr('Forecast:', 'ការព្យាករណ៍៖')} ${item['predicted_sales'] ?? 0} ${tr('units/day', 'ឯកតា/ថ្ងៃ')}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isHighRisk
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      tr('ON HAND', 'ស្តុកបច្ចុប្បន្ន'),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Text(
                                      '$stock',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: getStockColor(stock),
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 28,
                                      child: OutlinedButton(
                                        onPressed: () => sellItem(skuCode),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF0F172A,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          tr('Deduct', 'ដកចេញ'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "manualBtn",
            onPressed: showManualEntryDialog,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 2,
            child: const Icon(Icons.keyboard),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "uploadBtn",
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (image != null && context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(tr('Image Processed', 'រូបភាពបានដំណើរការ')),
                    content: const Text(
                      'Computer vision module requires backend initialization.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(tr('Acknowledge', 'យល់ព្រម')),
                      ),
                    ],
                  ),
                );
              }
            },
            backgroundColor: const Color(0xFF334155),
            icon: const Icon(
              Icons.document_scanner,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              tr('Import', 'នាំចូល'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "scanBtn",
            onPressed: () async {
              var res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SimpleBarcodeScannerPage(),
                ),
              );
              if (res is String && res != '-1' && context.mounted) {
                receiveItem(res);
              }
            },
            backgroundColor: const Color(0xFF0F172A),
            icon: const Icon(
              Icons.barcode_reader,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              tr('Scan', 'ម៉ាស៊ីនថត'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
