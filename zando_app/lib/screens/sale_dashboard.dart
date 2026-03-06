// lib/screens/sale_dashboard.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

class SaleDashboard extends StatefulWidget {
  const SaleDashboard({super.key});

  @override
  State<SaleDashboard> createState() => _SaleDashboardState();
}

class _SaleDashboardState extends State<SaleDashboard> {
  int _currentIndex = 0;
  List inventory = [];
  bool isLoading = true;

  // POS Cart State: Maps SKU to CartItem object
  Map<String, Map<String, dynamic>> cart = {};

  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(
    text: "10",
  );

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    setState(() => isLoading = true);
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
      debugPrint("Error fetching inventory: $e");
    }
  }

  // --- POS CART LOGIC ---
  void _addToCart(Map item) {
    if (item['stock'] <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Item out of stock!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      final sku = item['sku'];
      if (cart.containsKey(sku)) {
        if (cart[sku]!['quantity'] < item['stock']) {
          cart[sku]!['quantity'] += 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not enough stock!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        cart[sku] = {'name': item['name'], 'sku': sku, 'quantity': 1};
      }
    });
  }

  int get _totalCartItems {
    return cart.values.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

  Future<void> _checkoutCart() async {
    if (cart.isEmpty) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    bool hasError = false;

    // Process each item in the cart using your new Orders API
    for (var item in cart.values) {
      try {
        final response = await http.post(
          Uri.parse('https://zando-inventory-backend.onrender.com/api/orders'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'sku_code': item['sku'],
            'quantity': item['quantity'],
            'customer_username':
                'POS_Walk_In', // Tracks that a cashier rang this up
            'product_name': item['name'],
          }),
        );
        if (response.statusCode != 200) hasError = true;
      } catch (e) {
        hasError = true;
      }
    }

    Navigator.pop(context); // Close loading

    if (!hasError) {
      setState(() => cart.clear());
      fetchInventory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Checkout Successful! Receipts saved.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Some items failed to process.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // --- RECEIVE STOCK LOGIC ---
  Future<void> _receiveStock() async {
    if (_skuController.text.isEmpty || _qtyController.text.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/inventory/receive',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sku_code': _skuController.text.trim(),
          'quantity': int.parse(_qtyController.text.trim()),
        }),
      );

      Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        _skuController.clear();
        fetchInventory(); // Refresh stock
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📦 Stock Received & Updated!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${data['detail']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 Connection Error.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- UI TABS ---

  Widget _buildPOSTab() {
    if (isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );

    return Column(
      children: [
        // Product Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final item = inventory[index];
              return InkWell(
                onTap: () => _addToCart(item),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.network(
                            item['image_url'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.inventory),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SKU: ${item['sku']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Stock: ${item['stock']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item['stock'] > 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // POS Cart Bottom Bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_cart, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Current Cart',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        '$_totalCartItems Items',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: cart.isEmpty ? null : _checkoutCart,
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text(
                    'CHECKOUT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiveTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Receive Warehouse Stock',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan barcodes to add items to inventory.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _skuController,
                decoration: InputDecoration(
                  labelText: 'SKU / Barcode',
                  prefixIcon: const Icon(Icons.barcode_reader),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to Add',
                  prefixIcon: const Icon(Icons.add_box),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _receiveStock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ADD TO INVENTORY',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Zando Cashier POS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchInventory,
            tooltip: 'Refresh Inventory',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
            tooltip: 'Log Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentIndex == 0 ? _buildPOSTab() : _buildReceiveTab(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        elevation: 20,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Point of Sale',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Receive Stock',
          ),
        ],
      ),
    );
  }
}
