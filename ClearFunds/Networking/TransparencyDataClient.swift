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
    /* TODO: add production and sandbox environments
     sandbox https://webapi.developers.erstegroup.com/api/csas/public/sandbox/v3/transparentAccounts
     production https://www.csas.cz/webapi/api/v3/transparentAccounts
     */
    enum Error: Swift.Error {
        case apiError(StatusCode)
        case unknownStatus(Int)
        
        enum StatusCode: Int {
            case apiKeyNotFound = 412
            case tooManyRequests = 429
            case invalidParameters = 400
        }
    }

    struct SortParameters: CustomStringConvertible {
        enum SortOrder {
            case asc // default value is asc when the sort parameter is omitted
            case desc
        }

        let sortField: String
        let order: SortOrder
        
        var description: String {
            "\(sortField) - \(order == .asc ? "ascending" : "descending")"
        }
    }
    
    struct PaginationParameters {
        let page: Int
        let pageSize: Int
    }
    
    // filter is applied to description and name of account
    var accounts: @Sendable (_ filter: String?,_ pagination: PaginationParameters?) async throws -> PaginatedResponse<Account>
    
    // filter is applied to sender.name, variableSymbol, constantSymbol and description
    var transactions: @Sendable (_ accountId: String,_ filter: String?,_ sort: [SortParameters]?,_ pagination: PaginationParameters?) async throws -> PaginatedResponse<Transaction>
}

extension TransparencyDataClient: DependencyKey {
    static let liveValue: TransparencyDataClient = Self { filter, pagination in
        print("requested accounts for '\(filter ?? "no filter")', page \(pagination?.page ?? 0)")
        
        var queryItems = Self.paginationQueryItems(pagination) + Self.filterQueryItems(filter)
        
        let request = try Self.request(with: "transparentAccounts", queryItems: queryItems)
        let data = try await Self.retrieveData(for: request)
        let originalResponse = try Self.jsonDecoder.decode(PaginatedResponse<Account>.self, from: data)
        let resultingPage = try Self.splitOnPagesAndFilter(
            originalResponse: originalResponse,
            filter: filter?.isEmpty == false ? { $0.name.lowercased().contains(filter!.lowercased()) } : nil,
            pagination: pagination
        )
        
        print("responded with \(resultingPage.items.count) accounts, queried '\(filter ?? "no filter")'," +
              "page \(resultingPage.pageNumber) out of \(resultingPage.pageCount) pages")
        
        return resultingPage
    }
    transactions: { accountId, filter, sorting, pagination in
        print("requested transactions for account '\(accountId)', filter '\(filter ?? "none")', " +
              "sorting '\(String(describing: sorting))', pagination \(String(describing: pagination))")
        
        var queryItems = Self.sortingQueryItems(sorting) +
        Self.paginationQueryItems(pagination) +
        Self.filterQueryItems(filter)
        
        let request = try Self.request(with: "transparentAccounts/\(accountId)/transactions", queryItems: queryItems)
        let data = try await Self.retrieveData(for: request)
        let originalResponse = try Self.jsonDecoder.decode(PaginatedResponse<Transaction>.self, from: data)
        let resultingPage = try Self.splitOnPagesAndFilter(
            originalResponse: originalResponse,
            filter: filter != nil ? { $0.sender.name?.lowercased().contains(filter!.lowercased()) ?? false } : nil,
            pagination: pagination
        )
        
        print("responded with \(resultingPage.items.count) transactions")
        
        return resultingPage
    }
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

extension DependencyValues {
    var dataProvider: TransparencyDataClient {
        get { self[TransparencyDataClient.self] }
        set { self[TransparencyDataClient.self] = newValue }
    }
}

private extension TransparencyDataClient {
    static func filterQueryItems(_ filter: String?) -> [URLQueryItem] {
        guard let filter else { return [] }
        
        return [URLQueryItem(name: "filter", value: filter)]
    }
    
    static func paginationQueryItems(_ pagination: PaginationParameters?) -> [URLQueryItem] {
        guard let pagination else { return [] }
        
        return [.init(name: "page", value: "\(pagination.page)"),
                .init(name: "size", value: "\(pagination.pageSize)")]
    }
    
    static func sortingQueryItems(_ sortParameters: [SortParameters]?) -> [URLQueryItem] {
        guard let sortParameters else { return [] }
        
        return sortParameters
            .map {
                [.init(name: "sort", value: "\($0.sortField)"),
                 .init(name: "order", value: "\($0.order == .asc ? "asc" : "desc")")]
            }
            .reduce([], { $0 + $1 })
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
    
    static func splitOnPagesAndFilter<T: Identifiable>(
        originalResponse: PaginatedResponse<T>,
        filter: ((T) -> Bool)?,
        pagination: PaginationParameters?) throws -> PaginatedResponse<T>
    {
        // Since I couldn't achieve proper filtering and pagination from the server side,
        // I had to write them on the client side.
        
        let result: [T] = originalResponse.items.filter(filter ?? { _ in true })
        
        guard result.isEmpty == false else {
            return PaginatedResponse(items: [], pageNumber: 0, pageSize: 0, pageCount: 0, nextPage: 0, recordCount: 0)
        }
        
        if let pagination {
            let pages = stride(from: 0, to: result.count, by: pagination.pageSize).map {
                Array(result[$0 ..< Swift.min($0 + pagination.pageSize, result.count)])
            }

            guard pagination.page < pages.count else { // Simulate a server error for non-existent pages.
                throw Error.apiError(.invalidParameters)
            }
            
            return PaginatedResponse(
                items: pages[pagination.page],
                pageNumber: pagination.page,
                pageSize: pagination.pageSize,
                pageCount: pages.count,
                nextPage: pagination.page + 1 < pages.count ? pagination.page + 1 : 0,
                recordCount: result.count)
        }
        
        return PaginatedResponse(
            items: result,
            pageNumber: 0,
            pageSize: result.count,
            pageCount: 1,
            nextPage: 0,
            recordCount: result.count)
    }
}
