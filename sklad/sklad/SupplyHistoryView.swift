//
//  SupplyHistoryView.swift
//  sklad
//

import SwiftUI

struct SupplyHistoryView: View {

    let itemId: UUID?
    @Environment(DataStore.self) private var dataStore

    init(itemId: UUID? = nil) {
        self.itemId = itemId
    }

    var body: some View {
        List {
            if dataStore.supplies.isEmpty {
                Text("История пуста")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dataStore.supplies) { supply in
                    NavigationLink {
                        SupplyDetailView(supply: supply)
                    }                     label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("№\(supply.number)")
                                    .font(.headline)
                                if let date = supply.date {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let who = supply.createdByUsername, !who.isEmpty {
                                    Text("Создал: \(who)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Text(supply.type == "in" ? "Поставка" : "Отгрузка")
                                .font(.subheadline)
                                .foregroundStyle(supply.type == "in" ? .green : .red)
                        }
                    }
                }
            }
        }
        .navigationTitle("История поставок")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await dataStore.loadSupplies(itemId: itemId)
        }
    }
}

struct SupplyDetailView: View {

    let supply: APISupply
    @State private var fullSupply: APISupply?
    @State private var loadError: String?

    private var lineItems: [APISupplyLineItem] {
        let items = fullSupply?.lineItems ?? supply.lineItems ?? []
        return items.sorted { ($0.itemName ?? "") < ($1.itemName ?? "") }
    }

    private var supplyToShow: APISupply { fullSupply ?? supply }

    var body: some View {
        List {
            if let who = supplyToShow.createdByUsername, !who.isEmpty {
                Section {
                    LabeledContent("Создал", value: who)
                }
            }
            Section("Позиции") {
                if lineItems.isEmpty && fullSupply == nil && loadError == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if let err = loadError {
                    Text("Ошибка: \(err)")
                        .foregroundStyle(.red)
                } else {
                    ForEach(lineItems) { line in
                        HStack {
                            Text(line.itemName ?? "?")
                            Text(line.sizeLabel)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(line.quantity) шт.")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("\(supplyToShow.type == "in" ? "Поставка" : "Отгрузка") №\(supplyToShow.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard supply.lineItems == nil || supply.lineItems?.isEmpty == true else { return }
            do {
                fullSupply = try await APIService.shared.fetchSupply(id: supply.id)
            } catch {
                let urlErr = error as? URLError
                let nsErr = error as NSError
                if urlErr?.code == .cancelled || nsErr.code == NSURLErrorCancelled { return }
                loadError = error.localizedDescription
            }
        }
    }
}
