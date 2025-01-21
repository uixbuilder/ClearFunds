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
    func cachingDidInterruptShowsAlert() async {
        let error = TransparencyDataClient.Error.apiError(.apiKeyNotFound)
        let store = TestStore(initialState: MainScreenRouter.State()) { MainScreenRouter() }
        
        await store.send(.lookupScreen(.delegate(.cachingDidInterrupt(error: error)))) {
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
        
        await store.receive(\.lookupScreen.resumeCaching) {
            $0.lookupScreen.accountsIsCaching = true
        }
        
        await store.receive(\.lookupScreen.nextPageResponse.success) {
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
    
    @Test
    func popoverPresentationLogic() async throws {
        let accountMock = Account.mock(with: 0)
        let store = TestStore(initialState: MainScreenRouter.State()) { MainScreenRouter() }
        
        await store.send(.showPopover) {
            $0.popover = $0.bookmarks
        }
        
        await store.send(.popover(.presented(.accountDidSelect(accountMock)))) {
            $0.path.append(.init(account: accountMock))
            $0.popover = nil
        }
    }
    
    @Test
    func alertPresentationLogic() async throws {
        let alertMock = AlertState<MainScreenRouter.Action.Alert> {
            TextState("")
        } actions: {
            ButtonState {
                TextState("Try again")
            }
        }
        let accountMock = Account.mock(with: 0)
        var pathMock = StackState<AccountInformationFeature.State>()
        pathMock.append(.init(account: accountMock))
        let elementIDMock = pathMock.ids.first!
        let store = TestStore(initialState: MainScreenRouter.State(path: pathMock, alert: alertMock)) { MainScreenRouter() }
        withDependencies: {
            $0.dataProvider = TransparencyDataClient {_,_ in fatalError() }
            transactions: {_,_,_,_ in throw TransparencyDataClient.Error.unexpectedResponseBody }
        }
        
        await store.send(.alert(.presented(.resumeLoading(id: elementIDMock)))) {
            $0.alert = nil
        }
        
        await store.receive(\.path[id: elementIDMock].resumeLoadingTransactions) { _ in
            // It is necessary to check that the right action was received by the store only,
            // as all child state changes already handled by appropriate tests.
            store.exhaustivity = .off
        }
    }
    
    @Test
    func bookmarkTogglingDelegationLogic() async throws {
        let accountMock = Account.mock(with: 0)
        let store = TestStore(initialState: MainScreenRouter.State()) { MainScreenRouter() }
        
        await store.send(.lookupScreen(.delegate(.bookmarkDidToggle(account: accountMock))))
        await store.receive(\.bookmarks.toggleBookmark, accountMock) {
            _ = $0.lookupScreen.$bookmarks.withLock { bookmarks in
                bookmarks.append(accountMock)
            }
            $0.bookmarks = BookmarksFeature.State(bookmarkAccounts: Shared(value: [accountMock]))
        }
    }
}
