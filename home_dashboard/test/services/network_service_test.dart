import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:home_dashboard/core/services/network_service.dart';

class MockHttpClient extends http.BaseClient {
  final int statusCode;
  final String body;

  MockHttpClient({
    required this.statusCode,
    required this.body,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      statusCode,
    );
  }
}

void main() {
  group('NetworkService', () {
    test('getWhoAmI returns response on success', () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: '{"network":"lan","ip":"192.168.1.100"}',
      );

      final service = NetworkService(client: mockClient);
      final response = await service.getWhoAmI();

      expect(response, isNotNull);
      expect(response!.network, 'lan');
      expect(response.ip, '192.168.1.100');
    });

    test('getWhoAmI returns null on HTTP error', () async {
      final mockClient = MockHttpClient(
        statusCode: 500,
        body: 'Internal Server Error',
      );

      final service = NetworkService(client: mockClient);
      final response = await service.getWhoAmI();

      expect(response, isNull);
    });

    test('getWhoAmI returns null on invalid JSON', () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: 'not valid json',
      );

      final service = NetworkService(client: mockClient);
      final response = await service.getWhoAmI();

      expect(response, isNull);
    });

    test('getWhoAmI handles missing fields gracefully', () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: '{}',
      );

      final service = NetworkService(client: mockClient);
      final response = await service.getWhoAmI();

      expect(response, isNotNull);
      expect(response!.network, 'internet');
      expect(response.ip, '');
    });
  });
}
