//
//  HistoryView.swift
//  sklad
//
//  История движений по товару.
//

import SwiftUI

struct HistoryView: View {

    @ObservedObject var item: Item

    private var groupedHistory: [(date: Date, records: [InventoryChange])] {
        let set = (item.history as? Set<InventoryChange>) ?? []
        let sorted = set.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        let calendar = Calendar.current
        let groupedDict = Dictionary(grouping: sorted) { change in
            change.date.map { calendar.startOfDay(for: $0) } ?? .distantPast
        }

        return groupedDict
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, records: $0.value) }
    }

    var body: some View {
        List {
            if groupedHistory.isEmpty {
                Text("История пуста")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedHistory, id: \.date) { group in
                    Section(header: Text(group.date, style: .date)) {
                        ForEach(group.records) { change in
                            historyRow(change)
                        }
                    }
                }
            }
        }
        .navigationTitle("История")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyRow(_ change: InventoryChange) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(change.sizeLabel ?? "")
                    .font(.headline)

                if let note = change.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                let amount = Int(change.amount)
                let sign = amount >= 0 ? "+" : "−"
                Text("\(sign)\(abs(amount))")
                    .font(.headline)
                    .foregroundStyle(amount >= 0 ? .green : .red)

                if let date = change.date {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        Text("Предпросмотр HistoryView доступен после настройки Core Data модели.")
            .padding()
    }
}

