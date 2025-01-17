//
//  PaginatedResponse.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation


// This is a generic type for all pageable responses.
// Supports dynamic coding for its container.
struct PaginatedResponse<T>: Equatable where T: Equatable {
    let items: [T]
    let pageNumber: Int
    let pageSize: Int
    let pageCount: Int
    let nextPage: Int
    let recordCount: Int
}

protocol PaginatableKeyed {
    static var collectionKey: String { get }
}

extension PaginatedResponse: Decodable where T: PaginatableKeyed, T: Decodable {
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        guard let itemsKey = DynamicCodingKeys(stringValue: T.collectionKey) else {
            throw DecodingError.dataCorruptedError(
                forKey: DynamicCodingKeys(stringValue: T.collectionKey)!,
                in: container,
                debugDescription: "Invalid key for items"
            )
        }
        pageNumber = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "pageNumber")!)
        pageSize = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "pageSize")!)
        pageCount = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "pageCount")!)
        nextPage = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "nextPage")!)
        recordCount = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "recordCount")!)
        items = try container.decode([T].self, forKey: itemsKey)
    }
}
