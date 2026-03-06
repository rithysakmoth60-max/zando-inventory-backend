// lib/screens/customer_dashboard.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'login_screen.dart';

class CustomerDashboard extends StatefulWidget {
  final bool isLoggedIn;

  const CustomerDashboard({super.key, required this.isLoggedIn});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List inventory = [];
  bool isLoading = true;
  bool isKhmer = false;
  Timer? _realtimeTimer;

  String tr(String en, String km) => isKhmer ? km : en;

  Future<void> fetchInventory() async {
    try {
      final response = await http.get(
        // 🚀 CHANGED TO CLOUD URL
        Uri.parse('https://zando-inventory-backend.onrender.com/api/inventory'),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            inventory = json.decode(response.body);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> processPaymentAndDeductStock(String skuCode) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            '🔄 Verifying KHQR Payment...',
            '🔄 កំពុងផ្ទៀងផ្ទាត់ការបង់ប្រាក់ KHQR...',
          ),
        ),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      final response = await http.post(
        // 🚀 CHANGED TO CLOUD URL
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/sell',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sku_code': skuCode, 'quantity': 1}),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  '✅ Payment Successful! Order Placed.',
                  '✅ បង់ប្រាក់ជោគជ័យ! ការបញ្ជាទិញបានសម្រេច។',
                ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          fetchInventory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('❌ Payment Failed.', '❌ ការបង់ប្រាក់បរាជ័យ។')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛑 Connection Error.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showKHQRDialog(Map item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'KHQR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr(
                  'Scan to Pay via ABA / Bakong',
                  'ស្កេនដើម្បីបង់ប្រាក់តាម ABA / បាគង',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 180,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${item['name']} - Size: ${item['size']}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => processPaymentAndDeductStock(item['sku']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    tr(
                      'Simulate Customer Scan',
                      'ក្លែងធ្វើការស្កេនរបស់អតិថិជន',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  tr('Cancel Order', 'បោះបង់ការបញ្ជាទិញ'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    fetchInventory();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchInventory();
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          tr('Zando Official Store', 'ហាងផ្លូវការ Zando'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => setState(() => isKhmer = !isKhmer),
            child: Text(
              isKhmer ? 'EN' : 'ខ្មែរ',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const CustomerDashboard(isLoggedIn: false),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(
                icon: const Icon(Icons.person, size: 20, color: Colors.white),
                label: Text(
                  tr('Login', 'ចូលគណនី'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: inventory.length,
                  itemBuilder: (context, index) {
                    final item = inventory[index];
                    final bool inStock = item['stock'] > 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                item['image_url'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: Colors.grey[100],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Size: ${item['size']}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      inStock
                                          ? tr('In Stock', 'មានក្នុងស្តុក')
                                          : tr('Sold Out', 'អស់ស្តុក'),
                                      style: TextStyle(
                                        color: inStock
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (inStock)
                                      ElevatedButton(
                                        onPressed: () {
                                          if (widget.isLoggedIn) {
                                            showKHQRDialog(item);
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  tr(
                                                    'Please sign in to purchase.',
                                                    'សូមចូលគណនីដើម្បីទិញ។',
                                                  ),
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const LoginScreen(),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          tr('Buy', 'ទិញ'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
