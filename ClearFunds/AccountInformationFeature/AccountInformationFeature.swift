//
//  AccountInformationFeature.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 18.01.2025.
//

import Foundation
import ComposableArchitecture


@Reducer
struct AccountInformationFeature {
    @ObservableState
    struct State: Equatable {
        let account: Account
        var transactions: IdentifiedArrayOf<Transaction> = []
        var isFavorite: Bool = false
        var isDataLoading: Bool = false
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action {
        case startLoadingTransactions
        case toggleFavoriteButtonTapped
        case dataResponse(Result<PaginatedResponse<Transaction>, Error>)
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)
        @CasePathable
        enum Alert {
            case retryDetailsLoading
        }
        @CasePathable
        enum Delegate {
            case toggleFavoriteState(id: Account.ID)
        }
    }
    
    let cachingPageSize: Int = 5
    
    @Dependency(\.dataProvider) var dataProvider
    
    private enum CancelID {
        case pageLoading
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startLoadingTransactions:
                state.isDataLoading = true
                state.transactions = []
                return makeLoadPageEffect(state.account.id, page: 0)
                
            case .toggleFavoriteButtonTapped:
                return .send(.delegate(.toggleFavoriteState(id: state.account.id)))
                
            case .dataResponse(.success(let response)):
                state.transactions.append(contentsOf: response.items)
                if state.transactions.count == 0 && response.pageNumber == 0 {
                    // Received an empty response on the first page.
                    state.isDataLoading = false
                    return .none
                }
                
                if (response.nextPage < response.pageCount && response.nextPage != 0) {
                    // There are more pages to load.
                    return makeLoadPageEffect(state.account.id, page: response.nextPage)
                }
                
                state.isDataLoading = false
                return .none
                
            case .dataResponse(.failure(let error)):
                state.isDataLoading = false
                state.alert = makeAlertState(with: error)
                return .none
                
            // TODO: move this case to parent reducer
            case .delegate(.toggleFavoriteState):
                state.isFavorite = !state.isFavorite
                return .none
                
            case .delegate:
                return .none
            
            case .alert(.presented(.retryDetailsLoading)):
                state.isDataLoading = true
                let nextPageIndex = state.transactions.count / cachingPageSize
                return makeLoadPageEffect(state.account.id, page: nextPageIndex)
            
            case .alert:
                return .none
            }
        }
        .ifLet(\.alert, action: \.alert)
    }
    
    private func makeAlertState(with error: any Error) -> AlertState<AccountInformationFeature.Action.Alert> {
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
            ButtonState(action: .retryDetailsLoading) {
                TextState("Try again")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        }
    }
    
    private func makeLoadPageEffect(_ accountId: String, page: Int)
    -> Effect<AccountInformationFeature.Action>
    {
        .run { send in
            await send(.dataResponse(Result {
                try await dataProvider.transactions(
                    accountId: accountId,
                    filter: nil,
                    sort: [.init(sortField: .processingDate, order: .desc)],
                    pagination: .init(page: page, pageSize: cachingPageSize))
            }))
        }
        .cancellable(id: CancelID.pageLoading, cancelInFlight: true)
    }
}
