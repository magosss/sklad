//
//  SettingsView.swift
//  sklad
//

import SwiftUI

struct SettingsView: View {

    @Environment(DataStore.self) private var dataStore
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Статистика") {
                    NavigationLink {
                        ReportsView(dataStore: dataStore)
                    } label: {
                        Label("Отчёт по остаткам", systemImage: "chart.bar.doc.horizontal")
                    }
                    NavigationLink {
                        SupplyHistoryView()
                    } label: {
                        Label("История поставок", systemImage: "clock.arrow.circlepath")
                    }
                }
                Section("Товары") {
                    NavigationLink {
                        ProductsListView()
                    } label: {
                        Label("Товары", systemImage: "shippingbox")
                    }
                }
                Section {
                    Button("Выйти", role: .destructive) {
                        authStore.logout()
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
