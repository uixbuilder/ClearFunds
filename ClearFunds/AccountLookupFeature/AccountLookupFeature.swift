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
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action {
        case queryDidChange(String)
        case startLoadingAccounts
        case dataResponse(Result<PaginatedResponse<Account>, Error>)
        case alert(PresentationAction<Alert>)
        enum Alert: Equatable {
            case retryAccountCaching
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
                return makeLoadPageEffect(state.query, page: 0)
                
            case .alert(.presented(.retryAccountCaching)):
                state.accountsIsCaching = true
                return makeLoadPageEffect(state.query, page: state.cachedAccounts.count / cachingPageSize)
                
            case .alert:
                return .none
                
            case .dataResponse(.success(let paginatedAccounts)):
                state.cachedAccounts.append(contentsOf: paginatedAccounts.items)
                
                if state.cachedAccounts.count == 0 && paginatedAccounts.pageNumber == 0 {
                    // Received an empty response on the first page.
                    state.accountsIsCaching = false
                    return .none
                }
                
                state.accounts = filterAccounts(state)
                
                if (paginatedAccounts.nextPage < paginatedAccounts.pageCount && paginatedAccounts.nextPage != 0) {
                    // There are more pages to load.
                    return makeLoadPageEffect(state.query, page: paginatedAccounts.nextPage)
                }
                
                state.accountsIsCaching = false
                return .none
                
            case .dataResponse(.failure(let error)):
                state.accountsIsCaching = false
                state.alert = makeAlertState(with: error)
                return .none
                
            case .queryDidChange(let query):
                // TODO: As this action might be called with high frequency,
                // it is necessary to add some debouncing for 'query' changes.
                // However, for precise adjustments, it would be nice to check it on real data and experiment with pageSize and waiting time.
                // Possible solutions could include using 'debounce' builder from Effect or ContinuousClock.
                
                state.query = query
                state.accounts = filterAccounts(state)
                return .none
            }
        }
        .ifLet(\.alert, action: \.alert)
    }
    
    // MARK: - Private Methods
    
    private func makeAlertState(with error: any Error) -> AlertState<AccountLookupFeature.Action.Alert> {
        return AlertState {
            switch error {
            case TransparencyDataClient.Error.apiError(.apiKeyNotFound):
                return TextState("API key not found. Please set up WEB-API-key environment variable.")
                
            case TransparencyDataClient.Error.apiError(.tooManyRequests):
                return TextState("Too many requests. Please try again later.")
                
            case TransparencyDataClient.Error.unknownStatus(let status):
                return TextState("Unknown HTTP status: \(status)")
                
            default:
                return TextState("Unknown error: \(error)")
            }
            
        } actions: {
            ButtonState(action: .retryAccountCaching) {
                TextState("Try again")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        }
    }
    
    private func makeLoadPageEffect(_ query: String, page: Int)
    -> Effect<AccountLookupFeature.Action>
    {
        .run { send in
            await send(.dataResponse(Result {
                try await dataProvider.accounts(query: query, page: page, pageSize: cachingPageSize)
            }))
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

extension AccountLookupFeature.Action: Equatable {
    static func == (lhs: AccountLookupFeature.Action, rhs: AccountLookupFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case let (.queryDidChange(lhsQuery), .queryDidChange(rhsQuery)):
            return lhsQuery == rhsQuery
            
        case let (.dataResponse(lhsResult), .dataResponse(rhsResult)):
            return areResultsEqual(lhs: lhsResult, rhs: rhsResult)
            
        case let (.alert(lhsPage), .alert(rhsPage)):
            return lhsPage == rhsPage
            
        default:
            return false
        }
    }
    
    private static func areResultsEqual(
        lhs: Result<PaginatedResponse<Account>, Error>,
        rhs: Result<PaginatedResponse<Account>, Error>) -> Bool
    {
        switch (lhs, rhs) {
        case let (.success(lhsResponse), .success(rhsResponse)):
            return lhsResponse == rhsResponse
            
        case let (.failure(lhsError), .failure(rhsError)):
            return String(describing: lhsError) == String(describing: rhsError)
            
        default:
            return false
        }
    }
}
