//
//  TransparencyDataClient+DependencyKey.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 10.03.2025.
//

import ComposableArchitecture


extension TransparencyDataClient: DependencyKey {
    static let liveValue: TransparencyDataClient = Self { filter, pagination in
        logger.debug("requested accounts for '\(filter ?? "no filter")', page \(pagination?.page ?? 0)")
        let environment = try Self.Environment.basedOnEnvironmentKey()
        var queryItems = Self.paginationQueryItems(pagination) + Self.filterQueryItems(filter)
        let request = try Self.request(with: environment, path: "transparentAccounts", queryItems: queryItems)
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
        
        logger.debug("responded with \(resultingPage.items.count) accounts, queried '\(filter ?? "no filter")', page \(resultingPage.pageNumber) out of \(resultingPage.pageCount) pages")
        
        return resultingPage
    }
    transactions: { accountId, filter, sorting, pagination in
        logger.debug("requested transactions for account '\(accountId, privacy: .sensitive)', filter '\(filter ?? "none")', sorting '\(String(describing: sorting))', pagination \(String(describing: pagination))")
        let environment = try Self.Environment.basedOnEnvironmentKey()
        var queryItems = Self.sortingQueryItems(sorting) +
        Self.paginationQueryItems(pagination) +
        Self.filterQueryItems(filter)
        
        let request = try Self.request(with: environment, path: "transparentAccounts/\(accountId)/transactions", queryItems: queryItems)
        let data = try await Self.retrieveData(for: request)
        let originalResponse = try Self.jsonDecoder.decode(PaginatedResponse<Transaction>.self, from: data)
        let resultingPage = try Self.splitOnPagesAndFilter(
            originalResponse: originalResponse,
            filter: filter?.isEmpty == false ? { $0.sender.name?.lowercased().contains(filter!.lowercased()) ?? false } : nil,
            pagination: pagination,
            sortedBy: { $0.processingDate > $1.processingDate }
        )
        
        logger.debug("responded with \(resultingPage.items.count) transactions")
        
        return resultingPage
    }
    
    static let previewValue = Self.makePreviewValue()
}

extension DependencyValues {
    var dataProvider: TransparencyDataClient {
        get { self[TransparencyDataClient.self] }
        set { self[TransparencyDataClient.self] = newValue }
    }
}
