// lib/screens/prediction_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PredictionScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final int currentStock;

  const PredictionScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.currentStock,
  });

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _predictionData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPrediction();
  }

  Future<void> _fetchPrediction() async {
    try {
      // 🚀 Asking your live Cloud AI for the prediction!
      // NOTE: Make sure this URL exactly matches your FastAPI route for predictions.
      final response = await http.get(
        Uri.parse(
          'https://zando-inventory-backend.onrender.com/api/predict/${widget.productId}',
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _predictionData = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Server returned an error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Cloud Connection Failed. Check your internet.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI Restock Analysis',
          style: TextStyle(color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text('Running Machine Learning Model...'),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _buildPredictionDashboard(),
    );
  }

  Widget _buildPredictionDashboard() {
    // 🚨 IMPORTANT: You MUST change these keys to match your FastAPI JSON response!
    // For example, if your FastAPI returns {"days_until_empty": 5}, change 'predicted_days' to 'days_until_empty'.
    final int daysLeft = _predictionData?['predicted_days'] ?? 0;
    final int suggestedOrder = _predictionData?['suggested_order_qty'] ?? 0;

    // Logic for the status color
    Color statusColor = daysLeft < 7 ? Colors.red : Colors.green;
    String statusText = daysLeft < 7
        ? "CRITICAL: Restock Immediately"
        : "HEALTHY: Stock Levels Stable";

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Header
          Text(
            widget.productName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Stock: ${widget.currentStock} units',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // The AI Prediction Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.auto_graph, size: 48, color: statusColor),
                const SizedBox(height: 16),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol(
                      "Days Until Empty",
                      "$daysLeft",
                      Icons.calendar_today,
                    ),
                    _buildStatCol(
                      "Suggested Order",
                      "$suggestedOrder",
                      Icons.add_shopping_cart,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // The "Action" Button for the Presentation
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Automated Purchase Order sent to supplier for $suggestedOrder units!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text(
                'Approve Automated Restock',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}
