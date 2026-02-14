//
//  CoreDataManager.swift
//  sklad
//
//  Core Data стек и сервис для работы с товарами склада.
//

import Foundation
import CoreData

/// Менеджер Core Data, оборачивающий NSPersistentContainer.
/// Модель задаётся программно в SkladModel.swift.
final class CoreDataManager {

    // MARK: - Singleton

    static let shared = CoreDataManager()

    // MARK: - Properties

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Init

    private init(inMemory: Bool = false) {
        let model = SkladModel.managedObjectModel
        container = NSPersistentContainer(name: "SkladModel", managedObjectModel: model)

        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save

    func saveContextIfNeeded() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            // В MVP просто логируем ошибку, без сложного восстановления.
            print("CoreData save error: \(error)")
        }
    }

    // MARK: - Item CRUD

    func fetchItems() -> [Item] {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Item.createdAt, ascending: true)
        ]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fetch items error: \(error)")
            return []
        }
    }

    @discardableResult
    func createItem(name: String, photoData: Data? = nil) -> Item {
        let item = Item(context: viewContext)
        item.id = UUID()
        item.name = name
        item.photoData = photoData
        let now = Date()
        item.createdAt = now
        item.updatedAt = now

        saveContextIfNeeded()
        return item
    }

    func deleteItem(_ item: Item) {
        viewContext.delete(item)
        saveContextIfNeeded()
    }

    func deleteSize(_ size: SizeQuantity) {
        viewContext.delete(size)
        saveContextIfNeeded()
    }

    // MARK: - Size & Inventory helpers

    /// Находит или создаёт запись по размеру для товара.
    private func sizeQuantity(for item: Item, sizeLabel: String) -> SizeQuantity {
        if let existing = (item.sizes as? Set<SizeQuantity>)?.first(where: { $0.sizeLabel == sizeLabel }) {
            return existing
        }

        let size = SizeQuantity(context: viewContext)
        size.id = UUID()
        size.sizeLabel = sizeLabel
        size.quantity = 0
        size.item = item
        return size
    }

    /// Применяет изменение количества для конкретного размера и записывает историю.
    func applyChange(
        for item: Item,
        sizeLabel: String,
        delta: Int,
        note: String? = nil,
        changeType: String = "manual_adjust"
    ) {
        guard delta != 0 else { return }

        let size = sizeQuantity(for: item, sizeLabel: sizeLabel)
        let newValue = Int(size.quantity) + delta
        size.quantity = Int32(max(0, newValue))

        let history = InventoryChange(context: viewContext)
        history.id = UUID()
        history.date = Date()
        history.changeType = changeType
        history.amount = Int32(delta)
        history.sizeLabel = sizeLabel
        history.note = note
        history.item = item

        item.updatedAt = Date()

        saveContextIfNeeded()
    }

    // MARK: - Supply

    func getNextSupplyNumber() -> Int32 {
        let request: NSFetchRequest<Supply> = Supply.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Supply.number, ascending: false)]
        request.fetchLimit = 1

        guard let last = try? viewContext.fetch(request).first else {
            return 1
        }
        return last.number + 1
    }

    func createSupply(type: String, lines: [(item: Item, sizeLabel: String, quantity: Int)]) {
        guard !lines.isEmpty else { return }

        let number = getNextSupplyNumber()
        let supply = Supply(context: viewContext)
        supply.id = UUID()
        supply.number = number
        supply.date = Date()
        supply.type = type

        for line in lines {
            let li = SupplyLineItem(context: viewContext)
            li.id = UUID()
            li.item = line.item
            li.sizeLabel = line.sizeLabel
            li.quantity = Int32(line.quantity)
            li.supply = supply
        }

        saveContextIfNeeded()

        let deltaSign = type == "in" ? 1 : -1
        for line in lines {
            applyChange(
                for: line.item,
                sizeLabel: line.sizeLabel,
                delta: line.quantity * deltaSign,
                note: nil,
                changeType: type
            )
        }
    }

    func fetchSupplies(limit: Int = 100) -> [Supply] {
        let request: NSFetchRequest<Supply> = Supply.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Supply.date, ascending: false)]
        request.fetchLimit = limit

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fetch supplies error: \(error)")
            return []
        }
    }
}

