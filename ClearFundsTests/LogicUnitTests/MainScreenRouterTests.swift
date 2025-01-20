//
//  MainScreenRouterTests.swift
//  ClearFundsTests
//
//  Created by Igor Fedorov on 20.01.2025.
//

import Foundation
import Testing
import ComposableArchitecture
@testable import ClearFunds


@MainActor
struct MainScreenRouterTests {
    @Test
    func toggleFavorite() async {
        let account = Account.mock(with: 0)
        let store = TestStore(initialState: MainScreenRouter.State()) { MainScreenRouter() }
        
        await store.send(.toggleFavorite(account)) { _ in
            store.state.$favoriteAccounts.withLock { favoriteAccounts in
                favoriteAccounts = [account]
            }
        }
        
        await store.send(.toggleFavorite(account)) { _ in
            store.state.$favoriteAccounts.withLock { favoriteAccounts in
                favoriteAccounts = []
            }
        }
    }
    
    @Test
    func cachingDidInterruptShowsAlert() async {
        let error = TransparencyDataClient.Error.apiError(.apiKeyNotFound)
        let store = TestStore(initialState: MainScreenRouter.State()) { MainScreenRouter() }
        
        await store.send(.showLookupScreen(.delegate(.cachingDidInterrupt(error: error)))) {
            $0.alert = AlertState {
                TextState("API key not found. Please set up WEB-API-key environment variable.")
            } actions: {
                ButtonState(action: .retryCaching) {
                    TextState("Try again")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            }
        }
    }
    
    @Test
    func retryCachingFromAlert() async {
        let accounts = Account.mocks(count: 10)
        let mockResponse = PaginatedResponse<Account>.mockPageResponse(accounts)
        let store = TestStore(initialState: MainScreenRouter.State(
            alert: AlertState {
                TextState("API key not found. Please set up WEB-API-key environment variable.")
            } actions: {
                ButtonState(action: .retryCaching) {
                    TextState("Try again")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            }
        ))
        { MainScreenRouter() }
        withDependencies: {
            $0.dataProvider = TransparencyDataClient(
                accounts: {_,_ in mockResponse},
                transactions: {_,_,_,_ in fatalError()})
        }
        
        await store.send(.alert(.presented(.retryCaching))) {
            $0.lookupScreen.accountsIsCaching = false
            $0.alert = nil
        }
        
        await store.receive(\.showLookupScreen.resumeCaching) {
            $0.lookupScreen.accountsIsCaching = true
        }
        
        await store.receive(\.showLookupScreen.nextPageResponse.success) {
            $0.lookupScreen.accountsIsCaching = false
            $0.lookupScreen.accounts = IdentifiedArray(uniqueElements: mockResponse.items)
            $0.lookupScreen.cachedAccounts = IdentifiedArray(uniqueElements: mockResponse.items)
        }
    }
    
    @Test
    func transactionLoadingFailedShowsAlert() async {
        let error = TransparencyDataClient.Error.apiError(.tooManyRequests)
        let store = TestStore(initialState: MainScreenRouter.State(
            path: StackState([AccountInformationFeature.State(account: .mock(with: 0))])
        ))
        { MainScreenRouter() }
        
        let id = store.state.path.ids.first!
        
        // Simulate transaction loading failure
        await store.send(.path(.element(id: id, action: .delegate(.transactionLoadingFailed(error))))) {
            $0.alert = AlertState {
                TextState("Too many requests. Please try again later.")
            } actions: {
                ButtonState(action: .resumeLoading(id: id)) {
                    TextState("Try again")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            }
        }
    }
}
