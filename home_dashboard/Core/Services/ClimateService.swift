import Foundation

class ClimateService {
    let network: NetworkManager
    init(network: NetworkManager) {
        self.network = network
    }
    // Stub methods
    func getCurrentState() async throws -> ClimateState { throw NSError() }
    func setTemperature(_ temp: Double) async throws {}
    func setMode(_ mode: HVACMode) async throws {}
}
