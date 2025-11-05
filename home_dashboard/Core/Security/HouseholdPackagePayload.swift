import Foundation

struct HouseholdPackagePayload: Codable {
    var homeAssistantBaseURL: String = ""
    var homeAssistantToken: String? = nil
    var frigateBaseURL: String = ""
    var wireGuardConfig: WireGuardConfig = WireGuardConfig()
}
