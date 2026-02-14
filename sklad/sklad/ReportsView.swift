//
//  ReportsView.swift
//  sklad
//

import SwiftUI

struct ReportsView: View {

    let dataStore: DataStore

    private var totalQuantity: Int {
        dataStore.items.reduce(0) { $0 + dataStore.totalQuantity(for: $1) }
    }

    private var topItems: [(item: APIItem, quantity: Int)] {
        dataStore.items
            .map { ($0, dataStore.totalQuantity(for: $0)) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        List {
            Section("Сводка") {
                HStack {
                    Text("Всего единиц на складе")
                    Spacer()
                    Text("\(totalQuantity)")
                        .font(.headline)
                        .monospacedDigit()
                }
                HStack {
                    Text("Наименований")
                    Spacer()
                    Text("\(dataStore.items.count)")
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            Section("Топ по остаткам") {
                if topItems.isEmpty {
                    Text("Данных пока нет")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(topItems, id: \.item.id) { pair in
                        HStack {
                            Text(pair.item.name)
                            Spacer()
                            Text("\(pair.quantity) шт.")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Отчёт")
        .navigationBarTitleDisplayMode(.inline)
    }
}
