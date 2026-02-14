//
//  DataStore.swift
//  sklad
//

import Foundation
import SwiftUI
import Observation

@Observable
final class DataStore {

    var items: [APIItem] = []
    var supplies: [APISupply] = []
    var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared

    func loadItems() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let loaded = try await api.fetchItems()
            await MainActor.run { items = loaded }
        } catch {
            guard !isCancellationError(error) else {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run { errorMessage = "Ошибка загрузки: \(error.localizedDescription)" }
        }
        await MainActor.run { isLoading = false }
    }

    func loadSupplies(itemId: UUID? = nil) async {
        do {
            let loaded = try await api.fetchSupplies(itemId: itemId)
            await MainActor.run { supplies = loaded }
        } catch {
            guard !isCancellationError(error) else { return }
            await MainActor.run { errorMessage = "Ошибка загрузки поставок" }
        }
    }

    func itemWithSizes(id: UUID) async -> APIItem? {
        do {
            return try await api.fetchItem(id: id)
        } catch {
            return items.first { $0.id == id }
        }
    }

    @discardableResult
    func createItem(name: String, photoData: Data?, itemDescription: String?) async -> Bool {
        do {
            let item = try await api.createItem(name: name, photoData: photoData, itemDescription: itemDescription)
            await MainActor.run { items.append(item) }
            return true
        } catch {
            await MainActor.run { errorMessage = "Ошибка создания: \(error.localizedDescription)" }
            return false
        }
    }

    func updateItem(id: UUID, name: String?, photoData: Data?, itemDescription: String?) async {
        do {
            let updated = try await api.updateItem(id: id, name: name, photoData: photoData, itemDescription: itemDescription)
            await MainActor.run {
                if let idx = items.firstIndex(where: { $0.id == id }) {
                    items[idx] = updated
                }
            }
        } catch {
            await MainActor.run { errorMessage = "Ошибка сохранения" }
        }
    }

    func deleteItem(id: UUID) async {
        do {
            try await api.deleteItem(id: id)
            await MainActor.run { items.removeAll { $0.id == id } }
        } catch {
            await MainActor.run { errorMessage = "Ошибка удаления" }
        }
    }

    @discardableResult
    func createSize(itemId: UUID, sizeLabel: String, barcode: String?) async -> Bool {
        do {
            _ = try await api.createSize(itemId: itemId, sizeLabel: sizeLabel, barcode: barcode)
            await loadItems()
            return true
        } catch {
            await MainActor.run { errorMessage = "Ошибка добавления размера: \(error.localizedDescription)" }
            return false
        }
    }

    func updateSize(itemId: UUID, sizeId: UUID, sizeLabel: String, barcode: String?) async {
        do {
            _ = try await api.updateSize(itemId: itemId, sizeId: sizeId, sizeLabel: sizeLabel, barcode: barcode)
            await loadItems()
        } catch {
            await MainActor.run { errorMessage = "Ошибка сохранения размера" }
        }
    }

    func deleteSize(itemId: UUID, sizeId: UUID) async {
        do {
            try await api.deleteSize(itemId: itemId, sizeId: sizeId)
            await loadItems()
        } catch {
            await MainActor.run { errorMessage = "Ошибка удаления размера" }
        }
    }

    /// Возвращает `true` при успешном сохранении, `false` при ошибке (сообщение в `errorMessage`).
    func createSupply(type: String, lines: [(itemId: UUID, sizeLabel: String, quantity: Int)]) async -> Bool {
        do {
            let supply = try await api.createSupply(type: type, lines: lines)
            await MainActor.run { supplies.insert(supply, at: 0) }
            await loadItems()
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        if (error as NSError).code == NSURLErrorCancelled { return true }
        if Task.isCancelled { return true }
        return false
    }

    func totalQuantity(for item: APIItem) -> Int {
        (item.sizes ?? []).reduce(0) { $0 + $1.quantity }
    }

    func availableQuantity(itemId: UUID, sizeLabel: String) -> Int {
        guard let item = items.first(where: { $0.id == itemId }) else { return 0 }
        return item.sizes?.first(where: { $0.sizeLabel == sizeLabel })?.quantity ?? 0
    }
}
