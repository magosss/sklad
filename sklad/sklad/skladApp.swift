//
//  skladApp.swift
//  sklad
//

import SwiftUI

@main
struct skladApp: App {

    @State private var dataStore = DataStore()
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            if authStore.isAuthenticated {
                MainTabView()
                    .environment(dataStore)
                    .environment(authStore)
                    .task {
                        await dataStore.loadItems()
                    }
                    .overlay(alignment: .top) {
                        if let msg = dataStore.errorMessage {
                            Text(msg)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.9))
                                .onTapGesture { dataStore.errorMessage = nil }
                                .transition(.move(edge: .top))
                                .animation(.easeInOut, value: dataStore.errorMessage)
                        }
                    }
            } else {
                LoginView()
                    .environment(authStore)
            }
        }
    }
}
