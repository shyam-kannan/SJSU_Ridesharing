import Foundation

// MARK: - Chat Service

class ChatService {
    static let shared = ChatService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Send Message

    func sendMessage(tripId: String, message: String) async throws -> Message {
        let request = SendMessageRequest(message: message)

        // NetworkManager.request already unwraps APIResponse<T>, so use Message directly
        let message: Message = try await network.request(
            endpoint: "/trips/\(tripId)/messages",
            method: .post,
            body: request,
            requiresAuth: true
        )

        return message
    }

    // MARK: - Get Messages

    func getMessages(tripId: String) async throws -> [Message] {
        // NetworkManager.request already unwraps APIResponse<T>, so use MessagesResponse directly
        let response: MessagesResponse = try await network.request(
            endpoint: "/trips/\(tripId)/messages",
            method: .get,
            requiresAuth: true
        )

        return response.messages
    }
}
