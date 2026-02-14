//
//  InventoryChange+CoreData.swift
//  sklad
//

import Foundation
import CoreData

@objc(InventoryChange)
public class InventoryChange: NSManagedObject {

}

extension InventoryChange {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InventoryChange> {
        return NSFetchRequest<InventoryChange>(entityName: "InventoryChange")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var changeType: String?
    @NSManaged public var amount: Int32
    @NSManaged public var sizeLabel: String?
    @NSManaged public var note: String?
    @NSManaged public var item: Item?
}

extension InventoryChange: Identifiable {

}
