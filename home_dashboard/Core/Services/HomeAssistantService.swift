import Foundation

class HomeAssistantService {
    let network: NetworkManager
    init(network: NetworkManager) {
        self.network = network
    }
    // Stub methods
    func getConfig() async throws -> Any { throw NSError() }
    func getStates() async throws -> [Any] { throw NSError() }
    func getState(entityId: String) async throws -> Any { throw NSError() }
    func callService(domain: String, service: String, data: [String: Any]) async throws {}
}
