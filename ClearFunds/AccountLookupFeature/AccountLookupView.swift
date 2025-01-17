//
//  AccountLookupView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import SwiftUI
import ComposableArchitecture


struct AccountLookupView: View {
    @Bindable var store: StoreOf<AccountLookupFeature>
    @State var query: String = ""
        
    var body: some View {
        NavigationStack {
            ZStack {
                List(store.accounts) { account in
                    NavigationLink(destination: AccountDetailView(account: account)) {
                        HStack {
                            Text(account.name)
                            Spacer()
                            Text("Balance: \(account.balance, format: .currency(code: account.currency ?? "USD"))")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search for account")
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Type the name")
            .onChange(of: query, { [store] _, newValue in
                store.send(.queryDidChange(newValue))
            })
            .toolbar {
                if store.state.accountsIsCaching {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                    }
                }
            }
        }
        .onAppear {
            store.send(.startLoadingAccounts)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    AccountLookupView(store: Store(initialState: AccountLookupFeature.State(query: "")) { AccountLookupFeature() })
}
