import 'dart:convert';

import 'package:http/http.dart' as http;

/// Talks to the Python insight engine in api/insights.py.
///
/// On the web the engine sits on the same Vercel domain, so relative URLs work.
/// For an Android build, pass the deployed URL:
///   flutter build apk --dart-define=API_BASE=https://your-app.vercel.app
class Api {
  static const _base = String.fromEnvironment('API_BASE');

  static Uri _url(String query) => _base.isEmpty
      ? Uri.base.resolve('/api/insights$query')
      : Uri.parse('$_base/api/insights$query');

  static Future<Map<String, dynamic>> insights(Map<String, dynamic> body) async {
    final res = await http.post(
      _url(''),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception('engine said ${res.statusCode}');
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> demoData() async {
    final res = await http.get(_url('?demo=data'));
    if (res.statusCode != 200) throw Exception('engine said ${res.statusCode}');
    return jsonDecode(res.body);
  }
}
