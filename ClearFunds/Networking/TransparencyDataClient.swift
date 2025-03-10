//
//  TransparencyDataClient.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation
import ComposableArchitecture


@DependencyClient
struct TransparencyDataClient: Loggable {
    @CasePathable
    enum Error: Swift.Error, Equatable {
        case apiError(StatusCode)
        case clientMisconfiguredError
        case unsupportedHTTPStatus(Int)
        case unexpectedResponseBody
        case connectionURLErrorCode(URLError.Code)
        
        enum StatusCode: Int {
            case apiKeyNotFound = 412
            case tooManyRequests = 429
            case invalidParameters = 400
        }
    }
    
    struct Environment {
        let apiKey: String
        let baseURL: URL
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
    
    // filter is applied to description and name of account
    var accounts: @Sendable (_ filter: String?,_ pagination: PaginationParameters?) async throws -> PaginatedResponse<Account>
    
    // filter is applied to sender.name, variableSymbol, constantSymbol and description
    var transactions: @Sendable (_ accountId: String,_ filter: String?,_ sort: [SortParameters]?,_ pagination: PaginationParameters?) async throws -> PaginatedResponse<Transaction>
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
            logger.error("Failed to fetch data from URL \(request.url?.absoluteString ?? "unknown")")
            throw .connectionURLErrorCode((error as? URLError)?.code ?? .unknown)
        }
        
        if let response = result.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) == false {
            logger.error("Response status code \(String(describing: result.response)) while fetching data from URL \(request.url?.absoluteString ?? "unknown")")
            if let statusError = Error.StatusCode(rawValue: response.statusCode) {
                throw Error.apiError(statusError)
            }
            else {
                throw Error.unsupportedHTTPStatus(response.statusCode)
            }
        }
        
        return result.data
    }
    
    static func request(with environment: Environment, path: String, queryItems: [URLQueryItem]?) throws(TransparencyDataClient.Error) -> URLRequest {
        let fullURL = environment.baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: true) else { throw Error.clientMisconfiguredError }
        components.queryItems = queryItems
        guard let url = components.url else { throw Error.clientMisconfiguredError }
        
        var request =  URLRequest(url: url)
        request.setValue(environment.apiKey, forHTTPHeaderField: "WEB-API-key")
        return request
    }
}
