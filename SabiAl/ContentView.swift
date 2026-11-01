//
//  ContentView.swift
//  SabiAl
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatViewModel = ChatViewModel()

    var body: some View {
        TabView {
            ChatView(viewModel: chatViewModel)
                .tabItem {
                    Label("Bisedë", systemImage: "bubble.left.and.bubble.right.fill")
                }
            AdminGateView(viewModel: chatViewModel)
                .tabItem {
                    Label("Admin", systemImage: "shield.lefthalf.filled")
                }
        }
        .tint(Color(red: 0.05, green: 0.68, blue: 0.64))
    }
}

#Preview {
    ContentView()
}
