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
            $0.dataProvider = TransparencyDataClient(accounts: {_,_,_ in await mockResponse(mockAccounts())})
        }
        
        await store.send(.queryDidChange("test")) {
            $0.query = "test"
        }
    }
    
    @Test
    func startLoadingAccountsSuccess() async {
        let mockAccounts = mockAccounts()
        let mockResponse = mockResponse(mockAccounts)
        let store = TestStore(initialState: AccountLookupFeature.State()) {
            AccountLookupFeature()
        } withDependencies: {
            $0.dataProvider = TransparencyDataClient(accounts: {_,_,_ in mockResponse})
        }
        
        await store.send(.startLoadingAccounts) {
            $0.cachedAccounts = []
            $0.accountsIsCaching = true
        }
        
        await store.receive(.dataResponse(.success(mockResponse))) {
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
            $0.dataProvider = TransparencyDataClient(accounts: {_,_,_ in
                throw TransparencyDataClient.Error.apiError(.tooManyRequests)
            })
        }
        
        await store.send(.startLoadingAccounts) {
            $0.cachedAccounts = []
            $0.accountsIsCaching = true
        }
        
        await store.receive(.dataResponse(.failure(TransparencyDataClient.Error.apiError(.tooManyRequests)))) {
            $0.accountsIsCaching = false
            $0.alert = AlertState {
                TextState("Too many requests. Please try again later.")
            } actions: {
                ButtonState(action: .retryAccountCaching) {
                    TextState("Try again")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            }
        }
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
            $0.dataProvider = TransparencyDataClient(accounts: { _,_,_ in mockResponse })
        }
        
        await store.send(.startLoadingAccounts) {
            $0.accountsIsCaching = true
            $0.cachedAccounts = []
        }
        
        await store.receive(.dataResponse(.success(mockResponse))) {
            $0.accountsIsCaching = false
        }
    }
    
    @Test
    func retryAccountCaching() async {
        let mockAccounts = mockAccounts(count: 10)
        let firstPageResponse = mockResponse(mockAccounts, pageSize: 5, pageNumber: 0)
        let secondPageResponse = mockResponse(mockAccounts, pageSize: 5, pageNumber: 1)
        
        let store = TestStore(
            initialState: AccountLookupFeature.State(
                cachedAccounts: IdentifiedArray(uniqueElements: firstPageResponse.items),
                accountsIsCaching: false,
                alert: AlertState { TextState("Test") }
            ))
        { AccountLookupFeature() } withDependencies: {
            $0.dataProvider = TransparencyDataClient(accounts: { _,_,_ in secondPageResponse })
        }
        
        await store.send(.alert(.presented(.retryAccountCaching))) {
            $0.accountsIsCaching = true
            $0.alert = nil
        }
        
        await store.receive(.dataResponse(.success(secondPageResponse))) {
            $0.cachedAccounts = IdentifiedArray(uniqueElements: mockAccounts)
            $0.accounts = IdentifiedArray(uniqueElements: mockAccounts)
            $0.accountsIsCaching = false
        }
    }
    
    // MARK: - Private Methods
    
    private func mockAccounts(count: Int = 5) -> [Account] {
        (0..<count).map { idx in
            Account(
                accountNumber: "0000-\(idx)000000000000",
                bankCode: "0800",
                transparencyFrom: Date(),
                transparencyTo: Date(),
                publicationTo: Date(),
                actualizationDate: Date(),
                balance: 100.20 * Double(idx),
                currency: "CZK",
                name: "Account \(idx)",
                iban: "CZ000\(idx)0000000000000000000"
            )
        }
    }
    
    private func mockResponse(_ mockAccounts: [Account], pageSize: Int? = nil, pageNumber: Int? = nil)
    -> PaginatedResponse<Account>
    {
        let pageSize = pageSize ?? mockAccounts.count
        let pageNumber = pageNumber ?? 0
        
        let pages = stride(from: 0, to: mockAccounts.count, by: pageSize).map {
            Array(mockAccounts[$0 ..< Swift.min($0 + pageSize, mockAccounts.count)])
        }
        
        return PaginatedResponse<Account>(
            items: pages[pageNumber],
            pageNumber: pageNumber,
            pageSize: pageSize,
            pageCount: pages.count,
            nextPage: pageNumber + 1 < pages.count ? pageNumber + 1 : 0,
            recordCount: mockAccounts.count
        )
    }
}
