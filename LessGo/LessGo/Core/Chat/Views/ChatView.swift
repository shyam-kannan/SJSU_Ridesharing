import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let tripId: String
    let otherPartyName: String
    let isDriver: Bool
    var includesTabBarClearance: Bool = true

    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var pollTimer: Timer?
    @State private var showQuickMessages = false

    private let chatService = ChatService.shared
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        } else if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == authVM.currentUser?.id
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(Color(hex: "F4F6F2"))
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }

        }
        .navigationBarHidden(true)
        .background(Color(hex: "F4F6F2"))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if showQuickMessages {
                    quickMessagePicker
                        .padding(.bottom, 6)
                }
                messageInputBar
                if includesTabBarClearance {
                    Color.clear.frame(height: 86)
                }
            }
            .background(Color(hex: "F4F6F2"))
        }
        .task {
            await loadMessages()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
        .alert("Chat Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Components

    private var chatHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 38, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                            )
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.85))
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "17191E"))
                        .frame(width: 42, height: 42)
                    Text(otherPartyName.prefix(1).uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "A3E635"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(otherPartyName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black.opacity(0.9))
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "84CC16")).frame(width: 6, height: 6)
                        Text(isDriver ? "Rider conversation" : "Driver conversation")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)
            Text("No messages yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
            Text("Send a message to start the conversation")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private var quickMessagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickMessage.allCases, id: \.rawValue) { quickMsg in
                    Button(action: {
                        messageText = quickMsg.rawValue
                        showQuickMessages = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: quickMsg.icon)
                                .font(.system(size: 12))
                            Text(quickMsg.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.brand)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "A3E635").opacity(0.20))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(.horizontal, 10)
    }

    private var messageInputBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation {
                    showQuickMessages.toggle()
                }
            }) {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(showQuickMessages ? .brand : .textTertiary)
            }

            HStack(spacing: 8) {
                TextField("Type a message...", text: $messageText)
                    .font(.system(size: 15))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSendMessage {
                            Task { await sendMessage() }
                        }
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
            )

            Button(action: {
                Task { await sendMessage() }
            }) {
                if isSending {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    ZStack {
                        Circle()
                            .fill(canSendMessage ? Color(hex: "17191E") : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(canSendMessage ? Color(hex: "A3E635") : .white)
                    }
                }
            }
            .disabled(!canSendMessage || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Functions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = deduplicatedMessages(try await chatService.getMessages(tripId: tripId))
            errorMessage = nil
        } catch {
            print("Failed to load messages (attempt 1): \(error)")
            // Notification-open path can race backend auth/session refresh briefly.
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                messages = deduplicatedMessages(try await chatService.getMessages(tripId: tripId))
                errorMessage = nil
            } catch {
                print("Failed to load messages (attempt 2): \(error)")
                errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to load messages"
            }
        }
    }

    private func sendMessage() async {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true
        let textToSend = trimmed
        messageText = ""
        showQuickMessages = false

        do {
            let newMessage = try await chatService.sendMessage(tripId: tripId, message: textToSend)
            messages = deduplicatedMessages(messages + [newMessage])
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Failed to send message: \(error)")
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to send message"
            messageText = textToSend // Restore message on error
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        isSending = false
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                do {
                    let newMessages = try await chatService.getMessages(tripId: tripId)
                    let normalized = deduplicatedMessages(newMessages)
                    await MainActor.run {
                        let oldIds = messages.map(\.id)
                        let newIds = normalized.map(\.id)
                        if oldIds != newIds || messages.count != normalized.count {
                            messages = normalized
                        }
                        if !normalized.isEmpty {
                            errorMessage = nil
                        }
                    }
                } catch {
                    print("Polling error: \(error)")
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func deduplicatedMessages(_ items: [Message]) -> [Message] {
        var seen = Set<String>()
        return items
            .sorted { $0.createdAt < $1.createdAt }
            .filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser, let senderName = message.senderName {
                    Text(senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 4)
                }

                Text(message.messageText)
                    .font(.system(size: 15))
                    .foregroundColor(isFromCurrentUser ? .white : .textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isFromCurrentUser {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(hex: "17191E"))
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                                    )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(message.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, 4)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ChatView(tripId: "123", otherPartyName: "John Doe", isDriver: true)
            .environmentObject(AuthViewModel())
    }
}
