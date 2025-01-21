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
    @CasePathable
    enum Error: Swift.Error, Equatable {
        case apiError(StatusCode)
        case unsupportedHTTPStatus(Int)
        case unexpectedResponseBody
        case connectionURLErrorCode(URLError.Code)
        
        enum StatusCode: Int {
            case apiKeyNotFound = 412
            case tooManyRequests = 429
            case invalidParameters = 400
        }
    }

    struct SortParameters: CustomStringConvertible {
        typealias SortField = String
        enum SortOrder {
            case asc // default value is asc when the sort parameter is omitted
            case desc
        }

        let sortField: SortField
        let order: SortOrder
        
        var description: String {
            "\(sortField) - \(order == .asc ? "ascending" : "descending")"
        }
    }
    
    struct PaginationParameters {
        let page: Int
        let pageSize: Int
    }
    
    private(set) static var apiKey = ProcessInfo.processInfo.environment["WEB-API-key"]
    
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
        let originalResponse: PaginatedResponse<Account>
        do {
            originalResponse = try Self.jsonDecoder.decode(PaginatedResponse<Account>.self, from: data)
        } catch {
            throw TransparencyDataClient.Error.unexpectedResponseBody
        }
        
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
            filter: filter?.isEmpty == false ? { $0.sender.name?.lowercased().contains(filter!.lowercased()) ?? false } : nil,
            pagination: pagination,
            sortedBy: { $0.processingDate > $1.processingDate }
        )
        
        print("responded with \(resultingPage.items.count) transactions")
        
        return resultingPage
    }
    
    static let previewValue = Self.makePreviewValue()
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

// MARK: - Private Common Methods

extension TransparencyDataClient {
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
    
    static func retrieveData(for request: URLRequest) async throws(TransparencyDataClient.Error) -> Data {
        let result: (data: Data, response: URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            throw .connectionURLErrorCode((error as? URLError)?.code ?? .unknown)
        }
        
        if let response = result.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) == false {
            if let statusError = Error.StatusCode(rawValue: response.statusCode) {
                throw Error.apiError(statusError)
            }
            else {
                throw Error.unsupportedHTTPStatus(response.statusCode)
            }
        }
        
        return result.data
    }
    
    static func setApiKeyForTestingPurposes(_ apiKey: String?) {
        Self.apiKey = apiKey
    }
    
    static func request(with path: String, queryItems: [URLQueryItem]?) throws(TransparencyDataClient.Error) -> URLRequest {
        guard let apiKey = Self.apiKey else {
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
}
