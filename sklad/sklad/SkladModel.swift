//
//  SkladModel.swift
//  sklad
//
//  Программное описание Core Data модели.
//

import Foundation
import CoreData

enum SkladModel {

    static var managedObjectModel: NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let itemEntity = NSEntityDescription()
        itemEntity.name = "Item"
        itemEntity.managedObjectClassName = "Item"

        let itemId = NSAttributeDescription()
        itemId.name = "id"
        itemId.attributeType = .UUIDAttributeType
        itemEntity.properties.append(itemId)

        let itemName = NSAttributeDescription()
        itemName.name = "name"
        itemName.attributeType = .stringAttributeType
        itemEntity.properties.append(itemName)

        let itemPhotoData = NSAttributeDescription()
        itemPhotoData.name = "photoData"
        itemPhotoData.attributeType = .binaryDataAttributeType
        itemPhotoData.isOptional = true
        itemEntity.properties.append(itemPhotoData)

        let itemDescription = NSAttributeDescription()
        itemDescription.name = "itemDescription"
        itemDescription.attributeType = .stringAttributeType
        itemDescription.isOptional = true
        itemEntity.properties.append(itemDescription)

        let itemCreatedAt = NSAttributeDescription()
        itemCreatedAt.name = "createdAt"
        itemCreatedAt.attributeType = .dateAttributeType
        itemCreatedAt.isOptional = true
        itemEntity.properties.append(itemCreatedAt)

        let itemUpdatedAt = NSAttributeDescription()
        itemUpdatedAt.name = "updatedAt"
        itemUpdatedAt.attributeType = .dateAttributeType
        itemUpdatedAt.isOptional = true
        itemEntity.properties.append(itemUpdatedAt)

        let sizeEntity = NSEntityDescription()
        sizeEntity.name = "SizeQuantity"
        sizeEntity.managedObjectClassName = "SizeQuantity"

        let sizeId = NSAttributeDescription()
        sizeId.name = "id"
        sizeId.attributeType = .UUIDAttributeType
        sizeEntity.properties.append(sizeId)

        let sizeLabel = NSAttributeDescription()
        sizeLabel.name = "sizeLabel"
        sizeLabel.attributeType = .stringAttributeType
        sizeLabel.isOptional = true
        sizeEntity.properties.append(sizeLabel)

        let sizeQuantity = NSAttributeDescription()
        sizeQuantity.name = "quantity"
        sizeQuantity.attributeType = .integer32AttributeType
        sizeQuantity.defaultValue = 0
        sizeEntity.properties.append(sizeQuantity)

        let sizeBarcode = NSAttributeDescription()
        sizeBarcode.name = "barcode"
        sizeBarcode.attributeType = .stringAttributeType
        sizeBarcode.isOptional = true
        sizeEntity.properties.append(sizeBarcode)

        let historyEntity = NSEntityDescription()
        historyEntity.name = "InventoryChange"
        historyEntity.managedObjectClassName = "InventoryChange"

        let historyId = NSAttributeDescription()
        historyId.name = "id"
        historyId.attributeType = .UUIDAttributeType
        historyEntity.properties.append(historyId)

        let historyDate = NSAttributeDescription()
        historyDate.name = "date"
        historyDate.attributeType = .dateAttributeType
        historyDate.isOptional = true
        historyEntity.properties.append(historyDate)

        let historyChangeType = NSAttributeDescription()
        historyChangeType.name = "changeType"
        historyChangeType.attributeType = .stringAttributeType
        historyChangeType.isOptional = true
        historyEntity.properties.append(historyChangeType)

        let historyAmount = NSAttributeDescription()
        historyAmount.name = "amount"
        historyAmount.attributeType = .integer32AttributeType
        historyEntity.properties.append(historyAmount)

        let historySizeLabel = NSAttributeDescription()
        historySizeLabel.name = "sizeLabel"
        historySizeLabel.attributeType = .stringAttributeType
        historySizeLabel.isOptional = true
        historyEntity.properties.append(historySizeLabel)

        let historyNote = NSAttributeDescription()
        historyNote.name = "note"
        historyNote.attributeType = .stringAttributeType
        historyNote.isOptional = true
        historyEntity.properties.append(historyNote)

        let itemToSizes = NSRelationshipDescription()
        itemToSizes.name = "sizes"
        itemToSizes.destinationEntity = sizeEntity
        itemToSizes.isOptional = true
        itemToSizes.deleteRule = .cascadeDeleteRule

        let sizeToItem = NSRelationshipDescription()
        sizeToItem.name = "item"
        sizeToItem.destinationEntity = itemEntity
        sizeToItem.maxCount = 1
        sizeToItem.minCount = 0
        itemToSizes.inverseRelationship = sizeToItem
        sizeToItem.inverseRelationship = itemToSizes

        itemEntity.properties.append(itemToSizes)
        sizeEntity.properties.append(sizeToItem)

        let itemToHistory = NSRelationshipDescription()
        itemToHistory.name = "history"
        itemToHistory.destinationEntity = historyEntity
        itemToHistory.isOptional = true
        itemToHistory.deleteRule = .cascadeDeleteRule

        let historyToItem = NSRelationshipDescription()
        historyToItem.name = "item"
        historyToItem.destinationEntity = itemEntity
        historyToItem.maxCount = 1
        historyToItem.minCount = 0
        itemToHistory.inverseRelationship = historyToItem
        historyToItem.inverseRelationship = itemToHistory

        itemEntity.properties.append(itemToHistory)
        historyEntity.properties.append(historyToItem)

        let supplyEntity = NSEntityDescription()
        supplyEntity.name = "Supply"
        supplyEntity.managedObjectClassName = "Supply"

        let supplyId = NSAttributeDescription()
        supplyId.name = "id"
        supplyId.attributeType = .UUIDAttributeType
        supplyEntity.properties.append(supplyId)

        let supplyNumber = NSAttributeDescription()
        supplyNumber.name = "number"
        supplyNumber.attributeType = .integer32AttributeType
        supplyEntity.properties.append(supplyNumber)

        let supplyDate = NSAttributeDescription()
        supplyDate.name = "date"
        supplyDate.attributeType = .dateAttributeType
        supplyDate.isOptional = true
        supplyEntity.properties.append(supplyDate)

        let supplyType = NSAttributeDescription()
        supplyType.name = "type"
        supplyType.attributeType = .stringAttributeType
        supplyType.isOptional = true
        supplyEntity.properties.append(supplyType)

        let lineItemEntity = NSEntityDescription()
        lineItemEntity.name = "SupplyLineItem"
        lineItemEntity.managedObjectClassName = "SupplyLineItem"

        let lineItemId = NSAttributeDescription()
        lineItemId.name = "id"
        lineItemId.attributeType = .UUIDAttributeType
        lineItemEntity.properties.append(lineItemId)

        let lineItemSizeLabel = NSAttributeDescription()
        lineItemSizeLabel.name = "sizeLabel"
        lineItemSizeLabel.attributeType = .stringAttributeType
        lineItemSizeLabel.isOptional = true
        lineItemEntity.properties.append(lineItemSizeLabel)

        let lineItemQuantity = NSAttributeDescription()
        lineItemQuantity.name = "quantity"
        lineItemQuantity.attributeType = .integer32AttributeType
        lineItemEntity.properties.append(lineItemQuantity)

        let supplyToLineItems = NSRelationshipDescription()
        supplyToLineItems.name = "lineItems"
        supplyToLineItems.destinationEntity = lineItemEntity
        supplyToLineItems.isOptional = true
        supplyToLineItems.deleteRule = .cascadeDeleteRule

        let lineItemToSupply = NSRelationshipDescription()
        lineItemToSupply.name = "supply"
        lineItemToSupply.destinationEntity = supplyEntity
        lineItemToSupply.maxCount = 1
        lineItemToSupply.minCount = 0
        supplyToLineItems.inverseRelationship = lineItemToSupply
        lineItemToSupply.inverseRelationship = supplyToLineItems

        let lineItemToItem = NSRelationshipDescription()
        lineItemToItem.name = "item"
        lineItemToItem.destinationEntity = itemEntity
        lineItemToItem.maxCount = 1
        lineItemToItem.minCount = 0

        supplyEntity.properties.append(supplyToLineItems)
        lineItemEntity.properties.append(lineItemToSupply)
        lineItemEntity.properties.append(lineItemToItem)

        model.entities = [itemEntity, sizeEntity, historyEntity, supplyEntity, lineItemEntity]
        return model
    }
}
