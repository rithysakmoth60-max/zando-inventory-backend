// lib/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:zando_app/api_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // This variable will hold our cloud data
  late Future<List<dynamic>> futureInventory;

  @override
  void initState() {
    super.initState();
    // Fetch the data exactly ONCE when the screen first loads
    futureInventory = ApiService.fetchInventory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Zando Live Inventory'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        // Optional: A refresh button for your presentation!
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                futureInventory = ApiService.fetchInventory();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: futureInventory,
        builder: (context, snapshot) {
          // 1. SHOW LOADING SPINNER
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. SHOW ERROR IF CLOUD CONNECTION FAILS
          else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Cloud Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          // 3. SHOW EMPTY STATE
          else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No inventory found in database.'));
          }

          // 4. DATA IS READY! BUILD THE LIST
          List<dynamic> inventoryList = snapshot.data!;

          return ListView.builder(
            itemCount: inventoryList.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              var item = inventoryList[index];

              // 🚨 IMPORTANT: Change 'product_name' and 'stock_level' to match
              // the EXACT column names you used in your Supabase database!
              String itemName = item['product_name'] ?? 'Unknown Item';
              int stockLevel = item['stock_level'] ?? 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: stockLevel < 10
                        ? Colors.red
                        : Colors.green,
                    child: Icon(
                      stockLevel < 10 ? Icons.warning : Icons.check,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    itemName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Current Stock: $stockLevel'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Later, we can make this click to a "Predict Restock" page!
                    print('Clicked on $itemName');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
