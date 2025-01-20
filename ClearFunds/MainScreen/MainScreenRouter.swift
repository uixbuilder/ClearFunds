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
        var bookmarks = BookmarksFeature.State()
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var popover: BookmarksFeature.State?
    }
    @CasePathable
    enum Action {
        case path(StackAction<AccountInformationFeature.State, AccountInformationFeature.Action>)
        case lookupScreen(AccountLookupFeature.Action)
        case bookmarks(BookmarksFeature.Action)
        case showPopover
        case alert(PresentationAction<Alert>)
        case popover(PresentationAction<BookmarksFeature.Action>)
        @CasePathable
        enum Alert: Equatable {
            case retryCaching
            case resumeLoading(id: StackElementID)
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.lookupScreen, action: \.lookupScreen) {
            AccountLookupFeature()
        }
        Scope(state: \.bookmarks, action: \.bookmarks) {
            BookmarksFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .path(.element(let id, .delegate(.transactionLoadingFailed(let error)))):
                state.alert = makeAlertState(with: error, action: .resumeLoading(id: id))
                return .none
                
            case .showPopover:
                state.popover = state.bookmarks
                return .none
                
            case .path:
                return .none
                
            case .lookupScreen(.delegate(.cachingDidInterrupt(let error))):
                state.alert = makeAlertState(with: error, action: .retryCaching)
                return .none
                
            case .lookupScreen(.delegate(.bookmarkDidToggle(let bookmark))):
                return .run { send in
                    await send(.bookmarks(.toggleBookmark(bookmark)))
                }
                
            case .lookupScreen:
                return .none
                
            case .popover(.presented(.accountDidSelect(let account))):
                state.path.append(AccountInformationFeature.State(account: account))
                state.popover = nil
                return .none
                
            case .bookmarks:
                return .none
                
            case .popover:
                return .none
                
            case .alert(.presented(.retryCaching)):
                return .run { send in
                    await send(.lookupScreen(.resumeCaching))
                }
                
            case .alert(.presented(.resumeLoading(let id))):
                return .run { send in
                    await send(.path(.element(id: id, action: .resumeLoadingTransactions)))
                }
                
            case .alert:
                return .none
            }
        }
        .ifLet(\.$popover, action: \.popover) {
            BookmarksFeature()
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
                
            case TransparencyDataClient.Error.unexpectedResponseBody:
                return TextState("Upgrade to a newer version of the app.")
                
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
