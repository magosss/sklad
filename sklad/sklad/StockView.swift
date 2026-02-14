//
//  StockView.swift
//  sklad
//

import SwiftUI
import UIKit

struct StockView: View {

    @Environment(DataStore.self) private var dataStore

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Склад")
                .task { await dataStore.loadItems() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if dataStore.isLoading && dataStore.items.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if dataStore.items.isEmpty {
            ContentUnavailableView {
                Label("Остатков нет", systemImage: "shippingbox")
            } description: {
                Text("Добавьте наименования в Настройках.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(dataStore.items) { item in
                    NavigationLink {
                        ItemDetailView(item: item, dataStore: dataStore)
                    } label: {
                        itemRow(for: item)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func itemRow(for item: APIItem) -> some View {
        HStack(spacing: 12) {
            itemThumbnail(item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("Всего: \(dataStore.totalQuantity(for: item)) шт.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func itemThumbnail(_ item: APIItem) -> some View {
        ItemThumbnailView(photo: item.photo, size: 44)
    }
}
