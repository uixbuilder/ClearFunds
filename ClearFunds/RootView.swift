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
            AccountLookupView(store: store.scope(state: \.lookupScreen, action: \.showLookupScreen))
        } destination: { detailStore in
            makeDetailsView(with: detailStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    func makeDetailsView(with detailsStore: Store<AccountInformationFeature.State, AccountInformationFeature.Action>)
    -> some View
    {
        let isFavorite = store.favoriteAccounts.contains(detailsStore.account)
        return AccountDetailView(store: detailsStore)
            .navigationTitle("Account Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { store.send(.toggleFavorite(detailsStore.account)) }) {
                        HStack {
                            Text(isFavorite ? "Remove From Favorites" :"Add To Favorites")
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundStyle(Color.yellow)
                        }
                    }
                    .buttonStyle(.borderedProminent)
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
