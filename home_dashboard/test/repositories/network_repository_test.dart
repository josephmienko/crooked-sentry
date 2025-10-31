import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:home_dashboard/core/models/network_type.dart';
import 'package:home_dashboard/core/repositories/network_repository.dart';
import 'package:home_dashboard/core/services/network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Clear shared preferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('NetworkRepository', () {
    test('getNetworkType fetches and caches network type', () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: '{"network":"vpn","ip":"10.8.0.2"}',
      );
      final service = NetworkService(client: mockClient);
      final repository = NetworkRepository(service: service);

      expect(repository.hasCached, false);
      expect(repository.cachedNetworkType, isNull);

      final type = await repository.getNetworkType();

      expect(type, NetworkType.vpn);
      expect(repository.hasCached, true);
      expect(repository.cachedNetworkType, NetworkType.vpn);
      expect(repository.clientIp, '10.8.0.2');
    });

    test('getNetworkType returns cached value on second call within expiry',
        () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: '{"network":"lan","ip":"192.168.1.50"}',
      );
      final service = NetworkService(client: mockClient);
      final repository = NetworkRepository(service: service);

      final type1 = await repository.getNetworkType();
      final type2 = await repository.getNetworkType();

      expect(type1, NetworkType.wifi);
      expect(type2, NetworkType.wifi);
      expect(repository.hasCached, true);
    });

    test('getNetworkType falls back to cached value on fetch failure',
        () async {
      // First request succeeds
      final service1 = NetworkService(
        client: MockHttpClient(
            statusCode: 200, body: '{"network":"lan","ip":"192.168.1.1"}'),
      );
      final repository = NetworkRepository(service: service1);

      final type1 = await repository.getNetworkType();
      expect(type1, NetworkType.wifi);

      // Invalidate to force a new fetch
      repository.invalidate();

      // Second request fails, but should return cached value from persistence
      final service2 = NetworkService(
        client: MockHttpClient(statusCode: 500, body: 'Error'),
      );
      final repository2 = NetworkRepository(service: service2);

      final type2 = await repository2.getNetworkType();
      expect(type2, NetworkType.wifi); // Should load from SharedPreferences
    });

    test('forceRefresh bypasses cache', () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: '{"network":"vpn","ip":"10.8.0.5"}',
      );
      final service = NetworkService(client: mockClient);
      final repository = NetworkRepository(service: service);

      await repository.getNetworkType();
      expect(repository.hasCached, true);

      // Force refresh should fetch again
      final type = await repository.getNetworkType(forceRefresh: true);
      expect(type, NetworkType.vpn);
    });

    test('invalidate clears in-memory cache but not disk', () async {
      final mockClient = MockHttpClient(
        statusCode: 200,
        body: '{"network":"lan","ip":"192.168.1.1"}',
      );
      final service = NetworkService(client: mockClient);
      final repository = NetworkRepository(service: service);

      await repository.getNetworkType();
      expect(repository.hasCached, true);

      repository.invalidate();

      expect(repository.hasCached, false);
      expect(repository.cachedNetworkType, isNull);
      expect(repository.clientIp, isNull);

      // But persisted value should still be available
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_known_network_type'), 'wifi');
    });
  });
}
