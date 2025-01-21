//
//  TransparencyDataClient+Preview.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 21.01.2025.
//

import Foundation
import ComposableArchitecture


extension TransparencyDataClient {
    static func makePreviewValue() -> TransparencyDataClient {
        Self { _, _ in
            PaginatedResponse(items: [
                Account(
                    accountNumber: "000000000000",
                    bankCode: "0800",
                    transparencyFrom: Date(),
                    transparencyTo: Date(),
                    publicationTo: Date(),
                    actualizationDate: Date(),
                    balance: 134134234.03,
                    currency: "CZK",
                    name: "Pavel Kolař",
                    iban: "CZ00949494940409409"),
                Account(
                    accountNumber: "000000000001",
                    bankCode: "0800",
                    transparencyFrom: Date(),
                    transparencyTo: Date(),
                    publicationTo: Date(),
                    actualizationDate: Date(),
                    balance: 134134234.03,
                    currency: "CZK",
                    name: "Pavel Kolař",
                    iban: "CZ00949494940409409"),
                Account(
                    accountNumber: "000000000002",
                    bankCode: "0800",
                    transparencyFrom: Date(),
                    transparencyTo: Date(),
                    publicationTo: Date(),
                    actualizationDate: Date(),
                    balance: 134134234.03,
                    currency: "CZK",
                    name: "Pavel Kolař",
                    iban: "CZ00949494940409409")], pageNumber: 0, pageSize: 3, pageCount: 1, nextPage: 0, recordCount: 3)
        }
        transactions: { _, _, _, pagination in
            let page = PaginatedResponse(
                items: IdentifiedArrayOf<Transaction>.chartPreviewData.elements,
                pageNumber: 0, pageSize: 0, pageCount: 0, nextPage: 0, recordCount: 0)
            
            return try TransparencyDataClient.splitOnPagesAndFilter(
                originalResponse: page,
                filter: nil,
                pagination: pagination)
        }
    }
    
    
    static func splitOnPagesAndFilter<T: Identifiable>(
        originalResponse: PaginatedResponse<T>,
        filter: ((T) -> Bool)?,
        pagination: PaginationParameters?,
        sortedBy: ((T,T) -> Bool)? = nil) throws(TransparencyDataClient.Error) -> PaginatedResponse<T>
    {
        // Since I couldn't achieve proper filtering and pagination from the server side,
        // I had to write them on the client side.
        
        let result: [T] = originalResponse.items
            .filter(filter ?? { _ in true })
            .sorted(by: sortedBy ?? { _, _ in false })
        
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
