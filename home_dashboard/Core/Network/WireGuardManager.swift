import Foundation

class WireGuardManager {
    func setupTunnel(config: WireGuardConfig) async throws {}
    func connect() async throws {}
    func disconnect() {}
    func getStatus() -> String { return "" }
    var isConnected: Bool { return false }
}
