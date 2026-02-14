//
//  RecordMovementView.swift
//  sklad
//
//  Запись движения по товару: выбор размера, количество, заметка.
//

import SwiftUI
import CoreData

struct RecordMovementView: View {

    @ObservedObject var item: Item

    @State private var selectedSizeLabel: String = ""
    @State private var amount: Int = 0
    @State private var note: String = ""

    private var sizesArray: [SizeQuantity] {
        let set = (item.sizes as? Set<SizeQuantity>) ?? []
        return set.sorted { ($0.sizeLabel ?? "") < ($1.sizeLabel ?? "") }
    }

    var body: some View {
        Form {
            Section("Размер") {
                if sizesArray.isEmpty {
                    Text("Добавьте размеры в карточке товара (Склад)")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Размер", selection: $selectedSizeLabel) {
                        Text("Выберите").tag("")
                        ForEach(sizesArray, id: \.objectID) { size in
                            let label = size.sizeLabel ?? ""
                            Text("\(label) (\(Int(size.quantity)) шт.)").tag(label)
                        }
                    }
                    .onAppear {
                        if selectedSizeLabel.isEmpty, let first = sizesArray.first?.sizeLabel {
                            selectedSizeLabel = first
                        }
                    }
                }
            }

            Section("Количество") {
                Stepper(value: $amount, in: -1000...1000) {
                    HStack {
                        Text("Изменение")
                        Spacer()
                        Text("\(amount >= 0 ? "+" : "")\(amount)")
                            .font(.headline)
                            .foregroundStyle(amount >= 0 ? .green : .red)
                            .monospacedDigit()
                    }
                }
            }

            Section("Заметка") {
                TextField("Необязательно", text: $note)
                    .textInputAutocapitalization(.sentences)
            }

            Section {
                Button {
                    recordMovement()
                } label: {
                    HStack {
                        Spacer()
                        Text("Сохранить")
                        Spacer()
                    }
                }
                .disabled(selectedSizeLabel.isEmpty || amount == 0)
            }
        }
        .navigationTitle(item.name ?? "Движение")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func recordMovement() {
        guard !selectedSizeLabel.isEmpty, amount != 0 else { return }

        CoreDataManager.shared.applyChange(
            for: item,
            sizeLabel: selectedSizeLabel,
            delta: amount,
            note: note.isEmpty ? nil : note,
            changeType: amount > 0 ? "in" : "out"
        )
        amount = 0
        note = ""
    }
}
