//
//  APIModels.swift
//  sklad
//

import Foundation

struct APIItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var photo: String?
    var itemDescription: String?
    var createdAt: Date?
    var updatedAt: Date?
    var sizes: [APISize]?

    enum CodingKeys: String, CodingKey {
        case id, name, photo
        case itemDescription = "item_description"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sizes
    }
}

struct APISize: Identifiable, Codable, Hashable {
    let id: UUID
    var sizeLabel: String
    var quantity: Int
    var barcode: String?

    enum CodingKeys: String, CodingKey {
        case id, quantity, barcode
        case sizeLabel = "size_label"
    }
}

struct APISupply: Identifiable, Codable {
    let id: UUID
    var number: Int
    var date: Date?
    var type: String
    var lineItems: [APISupplyLineItem]?
    var createdByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id, number, date, type
        case lineItems = "line_items"
        case createdByUsername = "created_by_username"
    }
}

struct APISupplyLineItem: Identifiable, Codable {
    let id: UUID
    var itemId: UUID?
    var itemName: String?
    var sizeLabel: String
    var quantity: Int

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case itemId = "item_id"
        case itemName = "item_name"
        case sizeLabel = "size_label"
    }
}

struct SupplyCreatePayload: Encodable {
    let type: String
    let lines: [SupplyLinePayload]
}

struct SupplyLinePayload: Encodable {
    let itemId: UUID
    let sizeLabel: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case sizeLabel = "size_label"
        case itemId = "item_id"
        case quantity
    }
}
