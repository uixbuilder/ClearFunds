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
    struct State {
        var lookupScreen = AccountLookupFeature.State()
    }
    
    enum Action {
        case showLookupScreen(AccountLookupFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.lookupScreen, action: \.showLookupScreen) {
            AccountLookupFeature()
        }
        Reduce { state, action in
            return .none
        }
    }
}
