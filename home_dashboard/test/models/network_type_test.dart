import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/models/network_type.dart';

void main() {
  group('NetworkType', () {
    test('fromString parses "lan" as wifi', () {
      expect(NetworkType.fromString('lan'), NetworkType.wifi);
      expect(NetworkType.fromString('LAN'), NetworkType.wifi);
    });

    test('fromString parses "vpn" as vpn', () {
      expect(NetworkType.fromString('vpn'), NetworkType.vpn);
      expect(NetworkType.fromString('VPN'), NetworkType.vpn);
    });

    test('fromString defaults to other for unknown values', () {
      expect(NetworkType.fromString('internet'), NetworkType.other);
      expect(NetworkType.fromString('unknown'), NetworkType.other);
      expect(NetworkType.fromString(''), NetworkType.other);
    });

    test('label returns correct human-readable strings', () {
      expect(NetworkType.wifi.label, 'Local Network');
      expect(NetworkType.vpn.label, 'VPN');
      expect(NetworkType.other.label, 'Internet');
    });
  });
}
