//
//  Item+CoreData.swift
//  sklad
//

import Foundation
import CoreData

@objc(Item)
public class Item: NSManagedObject {

}

extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var itemDescription: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var sizes: NSSet?
    @NSManaged public var history: NSSet?
}

extension Item: Identifiable {

}
