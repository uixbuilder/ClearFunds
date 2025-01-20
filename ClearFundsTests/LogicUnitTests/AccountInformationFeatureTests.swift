//
//  AccountInformationFeatureTests.swift
//  ClearFundsTests
//
//  Created by Igor Fedorov on 19.01.2025.
//

import Foundation
import Testing
import ComposableArchitecture
@testable import ClearFunds


@MainActor
struct AccountInformationFeatureTests {
    @Test
    func startLoadingTransactions() async {
        let transactions: IdentifiedArrayOf<Transaction> = .chartPreviewData
        let response = PaginatedResponse(
            items: transactions.elements,
            pageNumber: 0,
            pageSize: 50,
            pageCount: 1,
            nextPage: 0,
            recordCount: 50
        )
        
        let store = TestStore(
            initialState: AccountInformationFeature.State(account: .mock(with: 0), isDataLoading: false))
        { AccountInformationFeature() } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts:{_, _ in fatalError()},
                transactions: { _, _, _, _ in response }
            )
        }
        
        await store.send(.startLoadingTransactions) {
            $0.isDataLoading = true
            $0.transactions = []
        }
        
        await store.receive(\.nextPageResponse.success) {
            $0.transactions.append(contentsOf: transactions)
            $0.isDataLoading = false
        }
    }
    
    @Test
    func testDataResponseSuccess() async {
        let transactions: IdentifiedArrayOf<Transaction> = .chartPreviewData
        let response = PaginatedResponse(
            items: transactions.elements,
            pageNumber: 0,
            pageSize: 50,
            pageCount: 1,
            nextPage: 0,
            recordCount: 50
        )

        let store = TestStore(
            initialState: AccountInformationFeature.State(account: .mock(with: 0), isDataLoading: true))
        { AccountInformationFeature() } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts:{_, _ in fatalError()},
                transactions: { _, _, _, _ in fatalError()}
            )
        }
        
        await store.send(.nextPageResponse(.success(response))) {
            $0.transactions.append(contentsOf: transactions)
            $0.isDataLoading = false
        }
    }
    
    @Test
    func dataResponseFailure() async {
        let error = TransparencyDataClient.Error.apiError(.tooManyRequests)
        let store = TestStore(initialState: AccountInformationFeature.State(account: .mock(with: 0))) {
            AccountInformationFeature()
        } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in fatalError()},
                transactions: {_,_,_,_ in throw error})
        }
        
        await store.send(.startLoadingTransactions) {
            $0.isDataLoading = true
        }
        
        await store.receive(\.nextPageResponse.failure, error) {
            $0.isDataLoading = false
        }
        
        await store.receive(\.delegate.transactionLoadingFailed, error)
    }
    
    @Test
    func testRetryLoadingTransactions() async {
        let transactions = IdentifiedArrayOf(uniqueElements: IdentifiedArrayOf<Transaction>.chartPreviewData.elements.prefix(10))
        let firstPageResponse: PaginatedResponse<Transaction> = .mockPageResponse(transactions.elements,
                                                                                  pageSize: 5,
                                                                                  pageNumber: 0)
        
        let secondPageResponse: PaginatedResponse<Transaction> = .mockPageResponse(transactions.elements,
                                                                                   pageSize: 5,
                                                                                   pageNumber: 1)
        
        let store = TestStore(
            initialState: AccountInformationFeature.State(
                account: .mock(with: 0),
                transactions: IdentifiedArray(uniqueElements: firstPageResponse.items)
            ))
        { AccountInformationFeature() } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in fatalError()},
                transactions: {_,_,_,_ in secondPageResponse})
        }
        
        await store.send(.resumeLoadingTransactions) {
            $0.isDataLoading = true
        }
        
        await store.receive(\.nextPageResponse.success) {
            $0.transactions = transactions
            $0.isDataLoading = false
        }
    }
}
