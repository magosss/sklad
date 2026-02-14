//
//  Supply+CoreData.swift
//  sklad
//

import Foundation
import CoreData

@objc(Supply)
public class Supply: NSManagedObject {}

extension Supply {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Supply> {
        NSFetchRequest<Supply>(entityName: "Supply")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var number: Int32
    @NSManaged public var date: Date?
    @NSManaged public var type: String?
    @NSManaged public var lineItems: NSSet?
}

extension Supply: Identifiable {}
