//
//  RootView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 19.01.2025.
//

import SwiftUI
import ComposableArchitecture


struct RootView: View {
    @Bindable var store: StoreOf<MainScreenRouter>
    
    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            makeLookupView()
        } destination: { detailStore in
            makeDetailsView(with: detailStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    private func makeLookupView() -> some View {
        AccountLookupView(store: store.scope(state: \.lookupScreen, action: \.lookupScreen))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { store.send(.showPopover) }) {
                        HStack {
                            Text("Bookmarks")
                            Image(systemName: "bookmark.fill")
                        }
                    }
                    .popover(store: store.scope(state: \.$popover, action: \.popover))
                    { bookmarksStore in
                        BookmarksView(store: bookmarksStore)
                            .frame(width: 400, height: 500)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
    }
    
    private func makeDetailsView(with detailsStore: Store<AccountInformationFeature.State, AccountInformationFeature.Action>)
    -> some View
    {
        let bookmarksStore = store.scope(state: \.bookmarks, action: \.bookmarks)
        let isBookmark = bookmarksStore.state.bookmarkAccounts.contains(detailsStore.account)
        return AccountDetailView(store: detailsStore)
            .navigationTitle("Account Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { bookmarksStore.send(.toggleBookmark(detailsStore.account)) }) {
                        HStack {
                            Text(isBookmark ? "Remove Bookmark" :"Add Bookmark")
                            Image(systemName: isBookmark ? "bookmark.fill" : "bookmark")
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
    }
}

#Preview {
    RootView(store: Store(initialState: MainScreenRouter.State()) {
        MainScreenRouter()
    })
}
