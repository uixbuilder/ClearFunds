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
    private enum CodingKeys: CaseIterable, CodingKey {
        case items
        case pageNumber
        case pageSize
        case pageCount
        case nextPage
        case recordCount
        
        var stringValue: String { self.rawValue }
        
        var intValue: Int? { nil }
        
        init?(intValue: Int) {
            return nil
        }
        
        init?(rawValue: String) {
            guard let keyCase = Self.allCases.first(where: { $0.rawValue == rawValue }) else {
                return nil
            }
            
            self = keyCase
        }
        
        var rawValue: String {
            switch self {
            case .items: return T.collectionKey
            case .nextPage: return "nextPage"
            case .pageCount: return "pageCount"
            case .pageNumber: return "pageNumber"
            case .recordCount: return "recordCount"
            case .pageSize: return "pageSize"
            }
        }
    }
}
