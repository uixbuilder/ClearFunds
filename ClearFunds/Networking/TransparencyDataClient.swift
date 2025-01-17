//
//  TransparencyDataClient.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation
import ComposableArchitecture

@DependencyClient
struct TransparencyDataClient {
    enum Error: Swift.Error {
        case apiError(StatusCode)
        case unknownStatus(Int)
        
        enum StatusCode: Int {
            case apiKeyNotFound = 412
            case tooManyRequests = 429
            case invalidParameters = 400
        }
    }
    
    var accounts: @Sendable (_ query: String, _ page: Int?, _ pageSize: Int?) async throws -> PaginatedResponse<Account>
}

extension TransparencyDataClient {
    public static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}

extension TransparencyDataClient: DependencyKey {
    static let liveValue: TransparencyDataClient = Self(
        accounts: { query, page, pageSize in
            print("requested accounts for '\(query)', page \(page ?? 0)")
            
            let queryItems = Self.paginationQueryItems(page: page, pageSize: pageSize)
                             + [URLQueryItem(name: "filter", value: query)]
            
            let request = try Self.request(with: "transparentAccounts", queryItems: queryItems)
            let data = try await Self.retrieveData(for: request)
            let originalResponse = try Self.jsonDecoder.decode(PaginatedResponse<Account>.self, from: data)
            let resultingPage = try Self.splitOnPagesAndFilter(
                originalResponse: originalResponse,
                query: query,
                pageSize: pageSize,
                page: page
            )
            
            print("responded with \(resultingPage.items.count) accounts, queried '\(query)'," +
                  "page \(resultingPage.pageNumber) out of \(resultingPage.pageCount) pages")
            
            return resultingPage
        }
    )
    
    static func paginationQueryItems(page: Int?, pageSize: Int?) -> [URLQueryItem] {
        var result: [URLQueryItem] = []
        if let page {
            result.append(.init(name: "page", value: "\(page)"))
        }
        if let pageSize {
            result.append(.init(name: "size", value: "\(pageSize)"))
        }
        return result
    }
    
    static func retrieveData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) == false {
            if let statusError = Error.StatusCode(rawValue: response.statusCode) {
                throw Error.apiError(statusError)
            }
            else {
                throw Error.unknownStatus(response.statusCode)
            }
        }
        
        return data
    }
    
    static func request(with path: String, queryItems: [URLQueryItem]?) throws -> URLRequest {
        guard let apiKey = ProcessInfo.processInfo.environment["WEB-API-key"] else {
            throw Error.apiError(.apiKeyNotFound)
        }
        
        let apiBaseUrl = "https://webapi.developers.erstegroup.com/api/csas/public/sandbox/v3"
        guard var components = URLComponents(string: apiBaseUrl) else { throw Error.apiError(.invalidParameters) }
        
        components.queryItems = queryItems
        components.path += "/" + path
        guard let url = components.url else { throw Error.apiError(.invalidParameters) }
        
        var request =  URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "WEB-API-key")
        return request
    }
    
    static func splitOnPagesAndFilter(originalResponse: PaginatedResponse<Account>, query: String, pageSize: Int?, page: Int?)
    throws -> PaginatedResponse<Account>
    {
        // Since I couldn't achieve proper filtering and pagination from the server side,
        // I had to write them on the client side.
        let pageSize = pageSize ?? 50
        let page = page ?? 0
        let filteredAccounts = query.isEmpty ?
        originalResponse.items : originalResponse.items.filter { $0.name.lowercased().contains(query.lowercased()) }
        
        guard filteredAccounts.count > 0 else { // There are no results.
            return PaginatedResponse(items: [], pageNumber: page, pageSize: pageSize, pageCount: 0, nextPage: 0, recordCount: 0)
        }
        
        let pages = stride(from: 0, to: filteredAccounts.count, by: pageSize).map {
            Array(filteredAccounts[$0 ..< Swift.min($0 + pageSize, filteredAccounts.count)])
        }
        
        guard page < pages.count else { // Simulate a server error for non-existent pages.
            throw Error.apiError(.invalidParameters)
        }
        
        let accountsForCurrentPage = pages[page]
        
        return PaginatedResponse(
            items: accountsForCurrentPage,
            pageNumber: page,
            pageSize: pageSize,
            pageCount: pages.count,
            nextPage: page + 1 < pages.count ? page + 1 : 0,
            recordCount: filteredAccounts.count)
    }
}

extension DependencyValues {
    var dataProvider: TransparencyDataClient {
        get { self[TransparencyDataClient.self] }
        set { self[TransparencyDataClient.self] = newValue }
    }
}
