//
//  SizeQuantity+CoreData.swift
//  sklad
//

import Foundation
import CoreData

@objc(SizeQuantity)
public class SizeQuantity: NSManagedObject {

}

extension SizeQuantity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SizeQuantity> {
        return NSFetchRequest<SizeQuantity>(entityName: "SizeQuantity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var sizeLabel: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var barcode: String?
    @NSManaged public var item: Item?
}

extension SizeQuantity: Identifiable {

}
