//
//  ChatView.swift
//  SabiAl
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @AppStorage(BotSettings.Keys.botName) private var botName = BotSettings.Defaults.botName

    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle(botName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isTyping {
                        ProgressView()
                    }
                }
            }
            .alert("Gabim", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("Në rregull", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        Group {
                            if message.text.isEmpty {
                                // Placeholder while the reply streams in.
                                Color.clear.frame(height: 0)
                            } else {
                                MessageBubble(message: message, botName: botName)
                            }
                        }
                        .id(message.id)
                    }

                    if viewModel.isTyping {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id(ChatMessage(role: .assistant, text: "__typing__").id)
                    }
                }
                .padding(.vertical)
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) {
                    if viewModel.isTyping, let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Shkruani një mesazh…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())

            Button {
                let text = draft
                draft = ""
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping)
            .animation(.bouncy(duration: 0.3), value: draft.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let botName: String

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 3) {
                Text(message.text)
                    .selectionDisabled(false)
                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isUser ? Color.accentColor.opacity(0.92) : Color(.secondarySystemBackground),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .frame(maxWidth: 300, alignment: .leading)

            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == index ? 1.35 : 0.85)
                    .opacity(phase == index ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
        .tint(Color(red: 0.05, green: 0.68, blue: 0.64))
}
