//
//  AccountLookupFeature.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation
import ComposableArchitecture


@Reducer
struct AccountLookupFeature {
    @ObservableState
    struct State: Equatable {
        var query: String = ""
        var accounts: IdentifiedArrayOf<Account> = []
        var cachedAccounts: IdentifiedArrayOf<Account> = []
        var accountsIsCaching: Bool = false
    }
    @CasePathable
    enum Action: Equatable {
        case queryDidChange(String)
        case startLoadingAccounts
        case nextPageResponse(Result<PaginatedResponse<Account>, TransparencyDataClient.Error>)
        case delegate(Delegate)
        case resumeCaching
        @CasePathable
        enum Delegate: Equatable {
            case cachingDidInterrupt(error: TransparencyDataClient.Error)
        }
    }
    
    let cachingPageSize: Int = 5
    
    @Dependency(\.dataProvider) var dataProvider
    
    private enum CancelID: Hashable {
        case pageLoading
        case updateQuerySchedule
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startLoadingAccounts:
                state.cachedAccounts = []
                state.accountsIsCaching = true
                return makeLoadPageEffect("", page: 0)
                
            case .resumeCaching:
                state.accountsIsCaching = true
                let nextPageIndex = state.cachedAccounts.count / cachingPageSize
                return makeLoadPageEffect("", page:nextPageIndex)
                                
            case .nextPageResponse(.success(let paginatedAccounts)):
                state.cachedAccounts.append(contentsOf: paginatedAccounts.items)
                
                if state.cachedAccounts.count == 0 && paginatedAccounts.pageNumber == 0 {
                    // Received an empty response on the first page.
                    state.accountsIsCaching = false
                    return .none
                }
                
                state.accounts = filterAccounts(state)
                
                if (paginatedAccounts.nextPage < paginatedAccounts.pageCount && paginatedAccounts.nextPage != 0) {
                    // There are more pages to load.
                    return makeLoadPageEffect("", page: paginatedAccounts.nextPage)
                }
                
                state.accountsIsCaching = false
                return .none
                
            case .nextPageResponse(.failure(let error)):
                state.accountsIsCaching = false
                return .run { send in
                    await send(.delegate(.cachingDidInterrupt(error: error)))
                }
                
            case .queryDidChange(let query):
                // TODO: As this action might be called with high frequency,
                // it is necessary to add some debouncing for 'query' changes.
                // However, for precise adjustments, it would be nice to check it on real data and experiment with pageSize and waiting time.
                // Possible solutions could include using 'debounce' builder from Effect or ContinuousClock.
                
                state.query = query
                state.accounts = filterAccounts(state)
                return .none

            case .delegate:
                return .none
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func makeLoadPageEffect(_ query: String, page: Int) -> Effect<AccountLookupFeature.Action> {
        .run { send in
            await send(.nextPageResponse(Result {
                return try await dataProvider.accounts(query, .init(page: page, pageSize: cachingPageSize))
            }.mapError({ $0 as! TransparencyDataClient.Error })))
        }
        .cancellable(id: CancelID.pageLoading, cancelInFlight: true)
    }
    
    private func filterAccounts(_ state: AccountLookupFeature.State) -> IdentifiedArray<String, Account> {
        // TODO: It is too wasteful to filter all cached accounts on each page during caching.
        // More efficiently, it would be to apply only the filtered part of the last page.
        // Secondly, to improve the 'query' we can use a hash map with an inverted index approach
        // to search in previous results only.
        if state.query.isEmpty {
            return state.cachedAccounts
        }
        return state.cachedAccounts.filter { $0.name.lowercased().contains(state.query.lowercased()) }
    }
}
