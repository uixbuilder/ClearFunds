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
        let accounts = try await testParsing(for: PaginatedResponse<Account>.self)
        #expect(accounts.count > 0) // Assert that the accounts array is not empty
    }
    
    @Test
    func transactionsParsing() async throws {
        let transactions = try await testParsing(for: PaginatedResponse<Transaction>.self)
        #expect(transactions.count > 0) // Assert that the transactions array is not empty
    }
    
    private func testParsing<T>(for type: PaginatedResponse<T>.Type) async throws -> [T]
    where T: Decodable & PaginatableKeyed
    {
        let resourceName = String(describing: T.self) + "s" // Infer the resource name from the generic type
        
        guard let pathString = Bundle(for: BundleHelper.self).path(forResource: resourceName, ofType: "json") else {
            fatalError("\(resourceName).json not found")
        }
        
        let decodedObject = try TransparencyDataClient.jsonDecoder.decode(
            PaginatedResponse<T>.self,
            from: Data(contentsOf: URL(fileURLWithPath: pathString))
        )
        
        return decodedObject.items // Return the array of items
    }
}
