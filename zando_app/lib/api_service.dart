// lib/api/api_service.dart

import 'constants.dart';
import 'network_helper.dart';

class ApiService {
  // 📦 Fetch all Zando inventory
  static Future<List<dynamic>> fetchInventory() async {
    String fullUrl = '${ApiConstants.baseUrl}${ApiConstants.inventoryEndpoint}';

    var data = await NetworkHelper.getData(fullUrl);

    if (data != null) {
      return data as List<dynamic>;
    } else {
      return []; // Return an empty list if it fails so the app doesn't crash
    }
  }

  // 🤖 Fetch Machine Learning Predictions for restocks
  static Future<Map<String, dynamic>?> fetchRestockPredictions(
    String productId,
  ) async {
    // Example of adding a query parameter to your URL
    String fullUrl =
        '${ApiConstants.baseUrl}${ApiConstants.predictEndpoint}?product_id=$productId';

    var data = await NetworkHelper.getData(fullUrl);

    return data;
  }
}
