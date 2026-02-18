import Foundation

// MARK: - Payment Service

class PaymentService {
    static let shared = PaymentService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Create Payment Intent

    func createPaymentIntent(bookingId: String, amount: Double) async throws -> Payment {
        let request = CreatePaymentIntentRequest(bookingId: bookingId, amount: amount)

        let payment: Payment = try await network.request(
            endpoint: "/payments/create-intent",
            method: .post,
            body: request
        )

        return payment
    }

    // MARK: - Capture Payment

    func capturePayment(id: String) async throws -> Payment {
        let payment: Payment = try await network.request(
            endpoint: "/payments/\(id)/capture",
            method: .post
        )
        return payment
    }

    // MARK: - Refund Payment

    func refundPayment(id: String) async throws -> Payment {
        let payment: Payment = try await network.request(
            endpoint: "/payments/\(id)/refund",
            method: .post
        )
        return payment
    }

    // MARK: - Cancel Payment

    func cancelPayment(id: String) async throws -> Payment {
        let payment: Payment = try await network.request(
            endpoint: "/payments/\(id)/cancel",
            method: .post
        )
        return payment
    }

    // MARK: - Get Payment by Booking

    func getPaymentByBooking(bookingId: String) async throws -> Payment {
        let payment: Payment = try await network.request(
            endpoint: "/payments/booking/\(bookingId)",
            method: .get
        )
        return payment
    }
}
