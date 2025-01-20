//
//  BookmarksFeatureTests.swift
//  ClearFundsTests
//
//  Created by Igor Fedorov on 20.01.2025.
//

import Testing
import ComposableArchitecture
@testable import ClearFunds


@MainActor
struct BookmarksFeatureTests {
    @Test
    func toggleBookmark() async {
        let account = Account.mock(with: 0)
        let store = TestStore(initialState: BookmarksFeature.State()) { BookmarksFeature() }
        
        await store.send(.toggleBookmark(account)) { _ in
            store.state.$bookmarkAccounts.withLock { bookmarkAccounts in
                bookmarkAccounts = [account]
            }
        }
        
        await store.send(.toggleBookmark(account)) { _ in
            store.state.$bookmarkAccounts.withLock { bookmarkAccounts in
                bookmarkAccounts = []
            }
        }
    }
}
