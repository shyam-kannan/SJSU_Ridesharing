import StripePaymentSheet
import Foundation
import Combine

@MainActor
final class StripePaymentManager: ObservableObject {
    static let shared = StripePaymentManager()

    @Published var paymentSheet: PaymentSheet?
    @Published var paymentResult: PaymentSheetResult?
    @Published var isConfigured = false

    private init() {}

    func configure() async {
        guard !isConfigured else { return }
        do {
            let key = try await fetchPublishableKey()
            StripeAPI.defaultPublishableKey = key
        } catch {
            StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
        }
        isConfigured = true
    }

    func preparePaymentSheet(clientSecret: String) {
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "LessGo Ridesharing"
        config.style = .automatic
        paymentResult = nil
        paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
    }

    private func fetchPublishableKey() async throws -> String {
        guard let url = URL(string: "\(APIConfig.baseURL)/config/stripe") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Response: Decodable {
            struct Data: Decodable { let publishableKey: String }
            let data: Data
        }
        return try JSONDecoder().decode(Response.self, from: data).data.publishableKey
    }
}
