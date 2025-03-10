//
//  TransparentDataClientTests.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 21.01.2025.
//

import XCTest
@testable import ClearFunds

final class TransparencyDataClientTests: XCTestCase {
    
    func testJSONDecoderConfiguration() {
        let decoder = TransparencyDataClient.jsonDecoder
        guard case .formatted(let formatter) = decoder.dateDecodingStrategy else {
            XCTFail()
            return
        }
        XCTAssertEqual(formatter.dateFormat, "yyyy-MM-dd'T'HH:mm:ss")
        XCTAssertEqual(formatter.timeZone, TimeZone(abbreviation: "UTC"))
        XCTAssertEqual(formatter.locale, Locale(identifier: "en_US_POSIX"))
    }
    
    func testFilterQueryItems_withValidFilter() {
        let queryItems = TransparencyDataClient.filterQueryItems("testFilter")
        XCTAssertEqual(queryItems.count, 1)
        XCTAssertEqual(queryItems.first?.name, "filter")
        XCTAssertEqual(queryItems.first?.value, "testFilter")
    }
    
    func testFilterQueryItems_withNilFilter() {
        let queryItems = TransparencyDataClient.filterQueryItems(nil)
        XCTAssertTrue(queryItems.isEmpty)
    }
    
    func testPaginationQueryItems_withValidPagination() {
        let pagination = TransparencyDataClient.PaginationParameters(page: 1, pageSize: 20)
        let queryItems = TransparencyDataClient.paginationQueryItems(pagination)
        
        XCTAssertEqual(queryItems.count, 2)
        XCTAssertEqual(queryItems[0].name, "page")
        XCTAssertEqual(queryItems[0].value, "1")
        XCTAssertEqual(queryItems[1].name, "size")
        XCTAssertEqual(queryItems[1].value, "20")
    }
    
    func testPaginationQueryItems_withNilPagination() {
        let queryItems = TransparencyDataClient.paginationQueryItems(nil)
        XCTAssertTrue(queryItems.isEmpty)
    }
    
    func testSortingQueryItems_withValidSortParameters() {
        let sortParameters = [
            TransparencyDataClient.SortParameters(sortField: "name", order: .asc),
            TransparencyDataClient.SortParameters(sortField: "date", order: .desc)]
        
        let queryItems = TransparencyDataClient.sortingQueryItems(sortParameters)
        
        XCTAssertEqual(queryItems.count, 4)
        XCTAssertEqual(queryItems[0].name, "sort")
        XCTAssertEqual(queryItems[0].value, "name")
        XCTAssertEqual(queryItems[1].name, "order")
        XCTAssertEqual(queryItems[1].value, "asc")
        XCTAssertEqual(queryItems[2].name, "sort")
        XCTAssertEqual(queryItems[2].value, "date")
        XCTAssertEqual(queryItems[3].name, "order")
        XCTAssertEqual(queryItems[3].value, "desc")
    }
    
    func testSortingQueryItems_withNilSortParameters() {
        let queryItems = TransparencyDataClient.sortingQueryItems(nil)
        XCTAssertTrue(queryItems.isEmpty)
    }
    
    func testRetrieveData_connectionErrorResponse() async {
        let invalidURL = URL(string: "https://very-invalid-url.com")!
        let request = URLRequest(url: invalidURL)
        
        do {
            _ = try await TransparencyDataClient.retrieveData(for: request)
            XCTFail("Expected to throw, but no error was thrown.")
        } catch {
            XCTAssertEqual(error, .connectionURLErrorCode(.cannotFindHost))
        }
    }
    
    func testRequest_withValidPathAndQueryItems() throws {
        let path = "accounts"
        let queryItems = [URLQueryItem(name: "filter", value: "active")]
        let environment = try TransparencyDataClient.Environment.basedOnApiKey("mockApiKey")
        
        let request = try TransparencyDataClient.request(with: environment, path: path, queryItems: queryItems)
        
        XCTAssertTrue(request.url?.absoluteString.hasSuffix("?filter=active") ?? false)
        XCTAssertEqual(request.value(forHTTPHeaderField: "WEB-API-key"), "mockApiKey")
    }
    
    func testRequest_withMissingAPIKey() {
        unsetenv("WEB-API-key")
        XCTAssertThrowsError(try TransparencyDataClient.Environment.basedOnEnvironmentKey()) { error in
            XCTAssertEqual(error as? TransparencyDataClient.Error, .clientMisconfiguredError)
        }
    }
}
