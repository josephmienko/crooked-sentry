import 'dart:convert';
import 'package:http/http.dart' as http;

/// Response from the /whoami endpoint.
class WhoAmIResponse {
  final String network;
  final String ip;

  const WhoAmIResponse({
    required this.network,
    required this.ip,
  });

  factory WhoAmIResponse.fromJson(Map<String, dynamic> json) {
    return WhoAmIResponse(
      network: json['network'] as String? ?? 'internet',
      ip: json['ip'] as String? ?? '',
    );
  }
}

/// Stateless service for network detection via the /whoami endpoint.
class NetworkService {
  final http.Client _client;
  final String _baseUrl;

  NetworkService({
    http.Client? client,
    String baseUrl = '',
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  /// Fetch the client's network classification from the server.
  ///
  /// Returns null if the request fails or the response is invalid.
  Future<WhoAmIResponse?> getWhoAmI() async {
    try {
      final uri = Uri.parse('$_baseUrl/whoami');
      final response = await _client.get(
        uri,
        headers: {'Cache-Control': 'no-cache'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return WhoAmIResponse.fromJson(data);
      }
    } catch (_) {
      // Network errors, parse errors, etc. → return null
    }
    return null;
  }
}
