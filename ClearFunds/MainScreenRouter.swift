//
//  MainScreenRouter.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation
import ComposableArchitecture


// This is a root router whose responsibility is management of actions between feature routers.
@Reducer
struct MainScreenRouter {
    @ObservableState
    struct State: Equatable {
        var lookupScreen = AccountLookupFeature.State()
        var path = StackState<AccountInformationFeature.State>()
        @Shared(.favorites) var favoriteAccounts
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action {
        case path(StackAction<AccountInformationFeature.State, AccountInformationFeature.Action>)
        case showLookupScreen(AccountLookupFeature.Action)
        case toggleFavorite(Account)
        case alert(PresentationAction<Alert>)
        enum Alert: Equatable {
            case retryCaching
            case resumeLoading(id: StackElementID)
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.lookupScreen, action: \.showLookupScreen) {
            AccountLookupFeature()
        }
        Reduce { state, action in
            switch action {
            case .toggleFavorite(let account):
                state.$favoriteAccounts.withLock {
                    if $0.remove(account) == nil {
                        $0.append(account)
                    }
                }

                return .none
                
            case .path(.element(let id, .delegate(.transactionLoadingFailed(let error)))):
                state.alert = makeAlertState(with: error, action: .resumeLoading(id: id))
                return .none
                
            case .path:
                return .none
                
            case .showLookupScreen(.delegate(.cachingDidInterrupt(let error))):
                state.alert = makeAlertState(with: error, action: .retryCaching)
                return .none
                
            case .showLookupScreen:
                return .none
                
            case .alert(.presented(.retryCaching)):
                return .run { send in
                    await send(.showLookupScreen(.resumeCaching))
                }
                
            case .alert(.presented(.resumeLoading(let id))):
                return .run { send in
                    await send(.path(.element(id: id, action: .resumeLoadingTransactions)))
                }
                
            case .alert:
                return .none
            }
        }
        .ifLet(\.alert, action: \.alert)
        .forEach(\.path, action: \.path) {
            AccountInformationFeature()
        }
    }
    
    // MARK: - Private Methods
    
    private func makeAlertState(with error: any Error, action: Action.Alert) -> AlertState<MainScreenRouter.Action.Alert> {
        return AlertState {
            switch error {
            case TransparencyDataClient.Error.apiError(.apiKeyNotFound):
                return TextState("API key not found. Please set up WEB-API-key environment variable.")
                
            case TransparencyDataClient.Error.apiError(.tooManyRequests):
                return TextState("Too many requests. Please try again later.")
                
            case TransparencyDataClient.Error.unsupportedHTTPStatus(let status):
                return TextState("Unknown HTTP status: \(status)")
                
            default:
                return TextState("Unknown error: \(error)")
            }
            
        } actions: {
            ButtonState(action: action) {
                TextState("Try again")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        }
    }
}

extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<Account>>.Default {
    static var favorites: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "favorites.json")), default: []]
    }
}
