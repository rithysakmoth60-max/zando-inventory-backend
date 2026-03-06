// lib/screens/customer_dashboard.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'login_screen.dart';

class CustomerDashboard extends StatefulWidget {
  final bool isLoggedIn;
  final String username; // NEW: Tracks who is buying!

  // Defaults to Zando_VIP so your presentation never crashes
  const CustomerDashboard({
    super.key,
    required this.isLoggedIn,
    this.username = "Zando_VIP",
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;
  List inventory = [];
  List orderHistory = []; // NEW: Stores the user's past purchases
  bool isLoading = true;
  bool isOrdersLoading = false;
  bool isKhmer = false;
  Timer? _realtimeTimer;

  String tr(String en, String km) => isKhmer ? km : en;

  @override
  void initState() {
    super.initState();
    fetchInventory();
    if (widget.isLoggedIn) fetchOrders();

    _realtimeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentIndex == 0) fetchInventory();
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchInventory() async {
    try {
      final response = await http.get(
        Uri.parse('https://zando-inventory-backend.onrender.com/api/inventory'),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          inventory = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🚀 NEW: Fetch Orders from the Cloud
  Future<void> fetchOrders() async {
    setState(() => isOrdersLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/orders/${widget.username}',
        ),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          orderHistory = json.decode(response.body);
          isOrdersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isOrdersLoading = false);
    }
  }

  void _startBakongPayment(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BakongPaymentSheet(
        item: item,
        isKhmer: isKhmer,
        onPaymentSuccess: () {
          _processOrderToDatabase(item['sku'], item['name']);
        },
      ),
    );
  }

  // 🚀 CHANGED: Now saves a real order instead of just deducting stock!
  Future<void> _processOrderToDatabase(
    String skuCode,
    String productName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://zando-inventory-backend.onrender.com/api/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sku_code': skuCode,
          'quantity': 1,
          'customer_username': widget.username,
          'product_name': productName,
        }),
      );

      if (mounted && response.statusCode == 200) {
        fetchInventory(); // Update store
        fetchOrders(); // Update order history!
      }
    } catch (e) {
      debugPrint("Order Error: $e");
    }
  }

  // --- UI BUILDERS FOR TABS ---

  Widget _buildShopTab() {
    if (isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        childAspectRatio: 0.65,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final bool inStock = item['stock'] > 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    item['image_url'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
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
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Size: ${item['size']}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          inStock
                              ? tr('In Stock', 'មានស្តុក')
                              : tr('Sold Out', 'អស់ស្តុក'),
                          style: TextStyle(
                            color: inStock
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (inStock)
                          ElevatedButton(
                            onPressed: () {
                              if (widget.isLoggedIn) {
                                _startBakongPayment(item);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(tr('Buy', 'ទិញ')),
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
    );
  }

  // 🚀 NEW: The Animated Orders UI
  Widget _buildOrdersTab() {
    if (!widget.isLoggedIn) {
      return Center(
        child: Text(
          tr('Please login to view orders.', 'សូមចូលគណនីដើម្បីមើលការបញ្ជាទិញ។'),
        ),
      );
    }
    if (isOrdersLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }
    if (orderHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              tr('No Orders Yet', 'មិនទាន់មានការបញ្ជាទិញទេ'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Items you purchase will appear here.',
                'ទំនិញដែលអ្នកទិញនឹងបង្ហាញនៅទីនេះ។',
              ),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: orderHistory.length,
      itemBuilder: (context, index) {
        final order = orderHistory[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.green),
            ),
            title: Text(
              order['product_name'] ?? 'Unknown Item',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('SKU: ${order['sku_code']}  |  Qty: ${order['quantity']}'),
                const SizedBox(height: 4),
                Text(
                  order['order_date'],
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            trailing: const Text(
              "Paid",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFF0F172A),
          child: Text(
            widget.username[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.username,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(tr('Language', 'ភាសា')),
          trailing: Switch(
            value: isKhmer,
            activeColor: Colors.black,
            onChanged: (val) => setState(() => isKhmer = val),
          ),
        ),
        const Divider(),
        if (widget.isLoggedIn)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              tr('Log Out', 'ចាកចេញ'),
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const CustomerDashboard(isLoggedIn: false),
              ),
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.login, color: Colors.blue),
            title: Text(
              tr('Log In', 'ចូលគណនី'),
              style: const TextStyle(color: Colors.blue),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          tr('Zando', 'Zando'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentIndex == 0
            ? _buildShopTab()
            : _currentIndex == 1
            ? _buildOrdersTab()
            : _buildProfileTab(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1 && widget.isLoggedIn)
            fetchOrders(); // Refresh orders when clicked
        },
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        showSelectedLabels: true,
        showUnselectedLabels: false,
        elevation: 20,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.storefront),
            label: tr('Shop', 'ហាង'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long),
            label: tr('Orders', 'ការបញ្ជាទិញ'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: tr('Profile', 'គណនី'),
          ),
        ],
      ),
    );
  }
}

// --- BAKONG SHEET REMAINS THE SAME ---
class _BakongPaymentSheet extends StatefulWidget {
  final Map item;
  final bool isKhmer;
  final VoidCallback onPaymentSuccess;

  const _BakongPaymentSheet({
    required this.item,
    required this.isKhmer,
    required this.onPaymentSuccess,
  });

  @override
  State<_BakongPaymentSheet> createState() => _BakongPaymentSheetState();
}

class _BakongPaymentSheetState extends State<_BakongPaymentSheet> {
  int _paymentState = 0;

  void _simulateScan() async {
    setState(() => _paymentState = 1);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _paymentState = 2);
    widget.onPaymentSuccess();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          if (_paymentState == 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'KHQR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.shade100, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.qr_code_2,
                size: 200,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simulateScan,
                icon: const Icon(Icons.document_scanner),
                label: Text(
                  widget.isKhmer ? 'ក្លែងធ្វើការស្កេន' : 'Simulate Bakong Scan',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else if (_paymentState == 1) ...[
            const SizedBox(height: 60),
            const CircularProgressIndicator(color: Color(0xFFE53935)),
            const SizedBox(height: 24),
            Text(
              widget.isKhmer
                  ? 'កំពុងផ្ទៀងផ្ទាត់ធនាគារ...'
                  : 'Verifying with Bank...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
          ] else ...[
            const SizedBox(height: 40),
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 24),
            Text(
              widget.isKhmer ? 'បង់ប្រាក់ជោគជ័យ!' : 'Payment Successful!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}
