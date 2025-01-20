//
//  BookmarksFeature.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 20.01.2025.
//

import Foundation
import ComposableArchitecture


@Reducer
struct BookmarksFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.bookmarks) var bookmarkAccounts
    }
    
    @CasePathable
    enum Action: Equatable {
        case toggleBookmark(Account)
        case accountDidSelect(Account)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleBookmark(let account):
                state.$bookmarkAccounts.withLock {
                    if $0.remove(account) == nil {
                        $0.append(account)
                    }
                }
                
                return .none
                
            case .accountDidSelect:
                return .none
            }
        }
    }
}

extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<Account>>.Default {
    static var bookmarks: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "bookmarks.json")), default: []]
    }
}
