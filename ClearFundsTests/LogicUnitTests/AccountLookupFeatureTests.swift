//
//  AccountLookupFeatureTests.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation
import Testing
import ComposableArchitecture
@testable import ClearFunds


@MainActor
struct AccountLookupFeatureTests {
    @Test
    func queryDidChange() async {
        let store = TestStore(initialState: AccountLookupFeature.State()) {
            AccountLookupFeature()
        } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in .mockPageResponse(Account.mocks())},
                transactions: {_,_,_,_ in fatalError()})
        }
        
        await store.send(.queryDidChange("test")) {
            $0.query = "test"
        }
    }
    
    @Test
    func startLoadingAccountsSuccess() async {
        let mockAccounts = Account.mocks()
        let mockResponse: PaginatedResponse<Account> = .mockPageResponse(mockAccounts)
        let store = TestStore(initialState: AccountLookupFeature.State()) {
            AccountLookupFeature()
        } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in mockResponse},
                transactions: {_,_,_,_ in fatalError()})
        }
        
        await store.send(.startLoadingAccounts) {
            $0.cachedAccounts = []
            $0.accountsIsCaching = true
        }
        
        await store.receive(\.nextPageResponse.success, mockResponse) {
            $0.cachedAccounts = IdentifiedArray(uniqueElements: mockAccounts)
            $0.accounts = IdentifiedArray(uniqueElements: mockAccounts)
            $0.accountsIsCaching = false
        }
    }
    
    @Test
    func startLoadingAccountsFailure() async {
        let store = TestStore(initialState: AccountLookupFeature.State()) {
            AccountLookupFeature()
        } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in throw TransparencyDataClient.Error.apiError(.tooManyRequests)},
                transactions: {_,_,_,_ in fatalError()})
        }
        
        await store.send(.startLoadingAccounts) {
            $0.cachedAccounts = []
            $0.accountsIsCaching = true
        }
        
        await store.receive(\.nextPageResponse.failure, .apiError(.tooManyRequests)) {
            $0.accountsIsCaching = false
        }
        
        await store.receive(\.delegate.cachingDidInterrupt, .apiError(.tooManyRequests))
    }
    
    @Test
    func dataResponseEmptyFirstPage() async {
        let mockResponse = PaginatedResponse<Account>(
            items: [],
            pageNumber: 0,
            pageSize: 5,
            pageCount: 1,
            nextPage: 0,
            recordCount: 0
        )
        
        let store = TestStore(initialState: AccountLookupFeature.State()) {
            AccountLookupFeature()
        } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in mockResponse},
                transactions: {_,_,_,_ in fatalError()})
        }
        
        await store.send(.startLoadingAccounts) {
            $0.accountsIsCaching = true
            $0.cachedAccounts = []
        }
        
        await store.receive(\.nextPageResponse.success, mockResponse) {
            $0.accountsIsCaching = false
        }
    }
    
    @Test
    func retryAccountCaching() async {
        let mockAccounts = Account.mocks(count: 10)
        let firstPageResponse: PaginatedResponse<Account> = .mockPageResponse(mockAccounts, pageSize: 5, pageNumber: 0)
        let secondPageResponse: PaginatedResponse<Account> = .mockPageResponse(mockAccounts, pageSize: 5, pageNumber: 1)
        
        let store = TestStore(
            initialState: AccountLookupFeature.State(
                cachedAccounts: IdentifiedArray(uniqueElements: firstPageResponse.items),
                accountsIsCaching: false
            ))
        { AccountLookupFeature() } withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in secondPageResponse},
                transactions: {_,_,_,_ in fatalError()})
        }
        
        await store.send(\.resumeCaching) {
            $0.accountsIsCaching = true
        }
        
        await store.receive(\.nextPageResponse.success, secondPageResponse) {
            $0.cachedAccounts = IdentifiedArray(uniqueElements: mockAccounts)
            $0.accounts = IdentifiedArray(uniqueElements: mockAccounts)
            $0.accountsIsCaching = false
        }
    }
}
