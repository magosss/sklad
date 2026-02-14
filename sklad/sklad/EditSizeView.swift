//
//  EditSizeView.swift
//  sklad
//

import SwiftUI

struct EditSizeView: View {

    let item: APIItem
    let size: APISize
    let dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var barcode = ""
    @State private var isShowingScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Размер") {
                    TextField("Например, S, M, 48", text: $label)
                        .textInputAutocapitalization(.characters)
                }
                Section("Штрихкод") {
                    HStack {
                        TextField("Необязательно", text: $barcode)
                            .keyboardType(.numberPad)
                        Button { isShowingScanner = true } label: {
                            Image(systemName: "camera")
                        }
                    }
                }
            }
            .navigationTitle("Размер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                label = size.sizeLabel
                barcode = size.barcode ?? ""
            }
            .sheet(isPresented: $isShowingScanner) {
                BarcodeScannerView { code in
                    barcode = code
                    isShowingScanner = false
                }
            }
        }
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return }
        let trimmedCode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let bc = trimmedCode.isEmpty ? nil : trimmedCode
        Task {
            await dataStore.updateSize(itemId: item.id, sizeId: size.id, sizeLabel: trimmedLabel, barcode: bc)
            dismiss()
        }
    }
}
