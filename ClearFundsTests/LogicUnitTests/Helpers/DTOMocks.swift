//
//  DTOMocks.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 20.01.2025.
//

import Foundation
@testable import ClearFunds


extension Account {
    static func mock(with id: Int) -> Account {
        Account(
            accountNumber: "\(id)",
            bankCode: "0800",
            transparencyFrom: Date(),
            transparencyTo: Date(),
            publicationTo: Date(),
            actualizationDate: Date(),
            balance: 100.20 * Double(id),
            currency: "CZK",
            name: "Account \(id)",
            iban: "CZ000\(id)0000000000000000000"
        )
    }
    
    static func mocks(count: Int = 5) -> [Account] {
        (0..<count).map(Account.mock(with:))
    }
}

extension PaginatedResponse {
    static func mockPageResponse(_ mocks: [T], pageSize: Int? = nil, pageNumber: Int? = nil) -> Self {
        let pageSize = pageSize ?? mocks.count
        let pageNumber = pageNumber ?? 0
        
        let pages = stride(from: 0, to: mocks.count, by: pageSize).map {
            Array(mocks[$0 ..< Swift.min($0 + pageSize, mocks.count)])
        }
        
        return PaginatedResponse<T>(
            items: pages[pageNumber],
            pageNumber: pageNumber,
            pageSize: pageSize,
            pageCount: pages.count,
            nextPage: pageNumber + 1 < pages.count ? pageNumber + 1 : 0,
            recordCount: mocks.count
        )
    }
}
