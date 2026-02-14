//
//  SupplyLineItem+CoreData.swift
//  sklad
//

import Foundation
import CoreData

@objc(SupplyLineItem)
public class SupplyLineItem: NSManagedObject {}

extension SupplyLineItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SupplyLineItem> {
        NSFetchRequest<SupplyLineItem>(entityName: "SupplyLineItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var sizeLabel: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var item: Item?
    @NSManaged public var supply: Supply?
}

extension SupplyLineItem: Identifiable {}
