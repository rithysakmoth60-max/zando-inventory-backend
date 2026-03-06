// lib/api/network_helper.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkHelper {
  // 1. GET Request (For fetching data like your inventory list)
  static Future<dynamic> getData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Success! Convert the JSON string into a Dart map/list
        return jsonDecode(response.body);
      } else {
        print('Server Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Network Exception: $e');
      return null;
    }
  }

  // 2. POST Request (For sending data, like adding a new product)
  static Future<dynamic> postData(String url, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('Server Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Network Exception: $e');
      return null;
    }
  }
}
