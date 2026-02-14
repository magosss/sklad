//
//  AddMovementView.swift
//  sklad
//

import SwiftUI
import UIKit
import AudioToolbox

private enum MovementType: String, CaseIterable {
    case inBound = "Поставка"
    case outBound = "Отгрузка"
}

private struct DraftLine: Identifiable {
    var id: String { "\(item.id)_\(sizeLabel)" }
    let item: APIItem
    let sizeLabel: String
    var quantity: Int
}

struct AddMovementView: View {

    @Environment(DataStore.self) private var dataStore

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.items.isEmpty {
                    ContentUnavailableView {
                        Label("Нет товаров", systemImage: "shippingbox")
                    } description: {
                        Text("Добавьте наименования в Настройках.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    typeSelectionView
                }
            }
            .navigationTitle("Добавить")
            .navigationBarTitleDisplayMode(.inline)
            .task { await dataStore.loadItems() }
        }
    }

    private var typeSelectionView: some View {
        VStack(spacing: 16) {
            ForEach(MovementType.allCases, id: \.self) { type in
                NavigationLink(value: type) {
                    Text(type.rawValue)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding()
        .navigationDestination(for: MovementType.self) { type in
            DraftSupplyView(items: dataStore.items, movementType: type, dataStore: dataStore)
        }
    }
}

// MARK: - Draft Supply

private struct DraftSupplyView: View {

    let items: [APIItem]
    let movementType: MovementType
    let dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var draftLines: [DraftLine] = []
    @State private var isShowingScanner = false
    @State private var isShowingAddSheet = false
    @State private var showConfirmSave = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var scanMessage: String?
    @State private var scanMessageIsError = false
    @State private var scanMessageTask: Task<Void, Never>?

    var body: some View {
        Group {
            if draftLines.isEmpty {
                ContentUnavailableView {
                    Label("Черновик пуст", systemImage: "tray")
                } description: {
                    Text("Добавьте товары кнопкой ниже или сканируйте штрихкод.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section("Товары") {
                        ForEach(draftLines) { line in
                            HStack(spacing: 12) {
                                itemThumb(line.item)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.item.name)
                                        .font(.headline)
                                    HStack(spacing: 4) {
                                        Text(line.sizeLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if movementType == .outBound {
                                            let avail = dataStore.availableQuantity(itemId: line.item.id, sizeLabel: line.sizeLabel)
                                            Text("• на складе \(avail)")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                Spacer()
                                if movementType == .outBound {
                                    Text("\(line.quantity)")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .frame(width: 60, alignment: .trailing)
                                } else {
                                    TextField("0", text: Binding(
                                        get: { "\(line.quantity)" },
                                        set: { newValue in
                                            guard let idx = draftLines.firstIndex(where: { $0.id == line.id }) else { return }
                                            if newValue.isEmpty {
                                                draftLines[idx].quantity = 0
                                            } else if let qty = Int(newValue.filter { $0.isNumber }) {
                                                draftLines[idx].quantity = max(0, qty)
                                            }
                                        }
                                    ))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                }
                            }
                        }
                        .onDelete(perform: removeLines)
                    }
                    if let err = saveError {
                        Section {
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.subheadline)
                        }
                    }
                    Section {
                        Button { saveError = nil; showConfirmSave = true } label: {
                            HStack {
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Сохранить")
                                }
                                Spacer()
                            }
                        }
                        .disabled(draftLines.isEmpty || !draftLines.contains { $0.quantity > 0 } || isSaving)
                    }
                }
            }
        }
        .navigationTitle(movementType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button { isShowingAddSheet = true } label: { Image(systemName: "plus.circle") }
                    Button { isShowingScanner = true } label: { Image(systemName: "camera") }
                }
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            NavigationStack {
                ZStack(alignment: .top) {
                    BarcodeScannerView(playFeedbackOnScan: false) { code in
                        addScanToDraft(code: code)
                    }
                    if let msg = scanMessage {
                        scanToast(message: msg, isError: scanMessageIsError)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Готово") { isShowingScanner = false }
                    }
                }
                .onDisappear {
                    scanMessageTask?.cancel()
                    scanMessage = nil
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddToDraftSheet(items: items, movementType: movementType, draftLines: draftLines) { lines in
                replaceDraftLinesForItem(lines: lines)
                if !lines.isEmpty {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                isShowingAddSheet = false
            }
        }
        .alert(movementType == .inBound ? "Поставка" : "Отгрузка", isPresented: $showConfirmSave) {
            Button("Отмена", role: .cancel) {}
            Button("Записать") { saveSupply() }
        } message: {
            Text(movementType == .inBound ? "Записать эту поставку?" : "Записать эту отгрузку?")
        }
    }

    private func itemThumb(_ item: APIItem) -> some View {
        ItemThumbnailView(photo: item.photo, size: 44)
    }

    private func addScanToDraft(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            do {
                let (itemId, sizeLabel) = try await APIService.shared.findByBarcode(trimmed)
                guard let item = items.first(where: { $0.id == itemId }) else {
                    showScanMessage("Штрихкод не найден", isError: true)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                if addOrMergeLine(DraftLine(item: item, sizeLabel: sizeLabel, quantity: 1)) {
                    showScanMessage("Добавлено: \(item.name), \(sizeLabel)", isError: false)
                    AudioServicesPlaySystemSound(1057)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    showScanMessage("Недостаточно на складе", isError: true)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            } catch {
                showScanMessage("Штрихкод не найден", isError: true)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func showScanMessage(_ text: String, isError: Bool) {
        scanMessageTask?.cancel()
        scanMessage = text
        scanMessageIsError = isError
        scanMessageTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { scanMessage = nil }
        }
    }

    private func scanToast(message: String, isError: Bool) -> some View {
        HStack {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? Color.red : Color.green)
            Text(message).font(.subheadline).foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .background(isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding()
    }

    @discardableResult
    private func addOrMergeLine(_ line: DraftLine) -> Bool {
        var qty = line.quantity
        if movementType == .outBound {
            let avail = dataStore.availableQuantity(itemId: line.item.id, sizeLabel: line.sizeLabel)
            qty = min(qty, avail)
            guard qty > 0 else { return false }
        }
        if let idx = draftLines.firstIndex(where: { $0.item.id == line.item.id && $0.sizeLabel == line.sizeLabel }) {
            let avail = movementType == .outBound ? dataStore.availableQuantity(itemId: line.item.id, sizeLabel: line.sizeLabel) : .max
            let oldQty = draftLines[idx].quantity
            let newQty = min(oldQty + qty, avail)
            draftLines[idx].quantity = newQty
            guard newQty > oldQty else { return false }
        } else {
            draftLines.append(DraftLine(item: line.item, sizeLabel: line.sizeLabel, quantity: qty))
        }
        return true
    }

    private func removeLines(at offsets: IndexSet) {
        draftLines.remove(atOffsets: offsets)
    }

    private func replaceDraftLinesForItem(lines: [DraftLine]) {
        guard let first = lines.first else { return }
        draftLines.removeAll { $0.item.id == first.item.id }
        for line in lines where line.quantity > 0 {
            draftLines.append(line)
        }
    }

    private func saveSupply() {
        let lines = draftLines.filter { $0.quantity > 0 }
        guard !lines.isEmpty else { return }
        saveError = nil
        isSaving = true
        let type = movementType == .inBound ? "in" : "out"
        let payload = lines.map { (itemId: $0.item.id, sizeLabel: $0.sizeLabel, quantity: $0.quantity) }
        Task {
            let success = await dataStore.createSupply(type: type, lines: payload)
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                } else {
                    saveError = dataStore.errorMessage ?? "Ошибка сохранения поставки"
                }
            }
        }
    }
}

// MARK: - Add to Draft Sheet

private struct AddToDraftSheet: View {
    let items: [APIItem]
    let movementType: MovementType
    let draftLines: [DraftLine]
    let onAdd: ([DraftLine]) -> Void

    var body: some View {
        NavigationStack {
            AddToDraftGridView(items: items, movementType: movementType, draftLines: draftLines, onAdd: onAdd)
        }
    }
}

private struct AddToDraftGridView: View {
    let items: [APIItem]
    let movementType: MovementType
    let draftLines: [DraftLine]
    let onAdd: ([DraftLine]) -> Void

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16),
         GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        VStack(spacing: 8) {
                            ItemThumbnailView(photo: item.photo, size: 80)
                                .aspectRatio(1, contentMode: .fit)
                            Text(item.name).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Добавить товар")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: APIItem.self) { item in
            AddItemLinesView(item: item, movementType: movementType, draftLines: draftLines) { lines in
                onAdd(lines)
            }
        }
    }

}

private struct AddItemLinesView: View {
    let item: APIItem
    let movementType: MovementType
    let draftLines: [DraftLine]
    let onAdd: ([DraftLine]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var quantityBySize: [String: Int] = [:]
    @State private var limitWarningForSize: String?
    @State private var limitWarningTask: Task<Void, Never>?

    private var sizesArray: [APISize] {
        (item.sizes ?? []).sorted { $0.sizeLabel < $1.sizeLabel }
    }

    var body: some View {
        Form {
            if sizesArray.isEmpty {
                Section { Text("Нет размеров").foregroundStyle(.secondary) }
            } else {
                sizesSection
                addButtonSection
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for line in draftLines where line.item.id == item.id {
                quantityBySize[line.sizeLabel] = line.quantity
            }
        }
        .onDisappear { limitWarningTask?.cancel() }
    }

    private var sizesSection: some View {
        Section("Размеры") {
            if let sizeLabel = limitWarningForSize {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Недостаточно на складе (\(sizeLabel))").font(.subheadline).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.orange.opacity(0.15))
            }
            ForEach(sizesArray) { size in
                let label = size.sizeLabel
                let avail = size.quantity
                let maxVal = movementType == .outBound ? avail : 9999
                let current = quantityBySize[label] ?? 0
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                        if movementType == .outBound {
                            Text("на складе \(avail)").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    quantityControls(label: label, current: current, maxVal: maxVal)
                }
            }
        }
    }

    private func quantityControls(label: String, current: Int, maxVal: Int) -> some View {
        HStack(spacing: 0) {
            Button {
                quantityBySize[label] = max(0, current - 1)
                limitWarningForSize = nil
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(current > 0 ? Color.accentColor : Color.gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(current <= 0)
            TextField("0", text: quantityBinding(label: label, maxVal: maxVal))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 48)
            Button {
                if current >= maxVal && movementType == .outBound {
                    limitWarningTask?.cancel()
                    limitWarningForSize = label
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    limitWarningTask = Task {
                        try? await Task.sleep(for: .seconds(2))
                        if !Task.isCancelled { limitWarningForSize = nil }
                    }
                } else {
                    quantityBySize[label] = min(current + 1, maxVal)
                    limitWarningForSize = nil
                }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    private func quantityBinding(label: String, maxVal: Int) -> Binding<String> {
        Binding(
            get: { "\(quantityBySize[label] ?? 0)" },
            set: { newValue in
                limitWarningForSize = nil
                if newValue.isEmpty {
                    quantityBySize[label] = 0
                } else if let qty = Int(newValue.filter { $0.isNumber }) {
                    let capped = movementType == .outBound ? min(qty, maxVal) : qty
                    quantityBySize[label] = max(0, capped)
                    if movementType == .outBound && qty > maxVal {
                        limitWarningForSize = label
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        limitWarningTask?.cancel()
                        limitWarningTask = Task {
                            try? await Task.sleep(for: .seconds(2))
                            if !Task.isCancelled { limitWarningForSize = nil }
                        }
                    }
                }
            }
        )
    }

    private var addButtonSection: some View {
        Section {
            Button { addToDraft() } label: {
                HStack { Spacer(); Text(movementType == .inBound ? "Добавить в поставку" : "Добавить в отгрузку"); Spacer() }
            }
            .disabled(!quantityBySize.values.contains { $0 > 0 })
        }
    }

    private func addToDraft() {
        var lines: [DraftLine] = []
        for size in sizesArray {
            var value = quantityBySize[size.sizeLabel] ?? 0
            guard value > 0 else { continue }
            if movementType == .outBound {
                value = min(value, size.quantity)
            }
            lines.append(DraftLine(item: item, sizeLabel: size.sizeLabel, quantity: value))
        }
        guard !lines.isEmpty else { return }
        onAdd(lines)
        dismiss()
    }
}

#Preview {
    AddMovementView()
        .environment(DataStore())
}
