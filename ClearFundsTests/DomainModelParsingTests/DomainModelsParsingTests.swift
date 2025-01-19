//
//  DomainModelsParsingTests.swift
//  DomainModelsParsingTests
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Testing
import Foundation
@testable import ClearFunds

class BundleHelper {}

struct DomainModelsParsingTests {
    @Test
    func accountsParsing() async throws {
        guard let pathString = Bundle(for: BundleHelper.self).path(forResource: "Accounts", ofType: "json") else {
            fatalError("Accounts.json not found")
        }
        
        let page = try TransparencyDataClient.jsonDecoder.decode(
            PaginatedResponse<Account>.self,
            from: Data(contentsOf: URL(fileURLWithPath: pathString))
        )
        
        #expect(page.items.count > 0)
    }
    
    @Test
    func transactionsParsing() async throws {
        guard let pathString = Bundle(for: BundleHelper.self).path(forResource: "Transactions", ofType: "json") else {
            fatalError("Transactions.json not found")
        }
        
        let page = try TransparencyDataClient.jsonDecoder.decode(
            PaginatedResponse<Transaction>.self,
            from: Data(contentsOf: URL(fileURLWithPath: pathString))
        )
        
        #expect(page.items.count > 0)
    }
}
