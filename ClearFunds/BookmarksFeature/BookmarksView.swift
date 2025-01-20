//
//  BookmarksView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 20.01.2025.
//

import SwiftUI
import ComposableArchitecture


struct BookmarksView: View {
    var store: StoreOf<BookmarksFeature>
    
    var body: some View {
        NavigationStack {
            if store.bookmarkAccounts.isEmpty {
                HStack {
                    Image(systemName: "bookmark")
                    Text("There are no bookmarks")
                }
            }
            else {
                List(store.bookmarkAccounts) { account in
                    HStack {
                        Text("\(account.name)")
                        Spacer()
                        Button(action: { store.send(.toggleBookmark(account)) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .tint(.red)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.send(.accountDidSelect(account))
                    }
                }
                .navigationTitle(Text("Bookmarked Accounts"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    BookmarksView(store: Store(initialState: BookmarksFeature.State()) { BookmarksFeature() })
}
