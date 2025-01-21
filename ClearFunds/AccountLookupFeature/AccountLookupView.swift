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
        ZStack {
            List(store.accounts) { account in
                NavigationLink(state: AccountInformationFeature.State(account: account)) {
                    HStack {
                        // TODO: Workaround for cell separator indentation level.
                        Text("").frame(width: 0)
                        
                        VStack {
                            Button(action: { store.send(.delegate(.bookmarkDidToggle(account: account))) }) {
                                VStack {
                                    Image(systemName: store.state.bookmarks.contains(account) ? "bookmark.fill" : "bookmark")
                                        .imageScale(.large)
                                        .offset(y: -4)
                                    Spacer()
                                }
                                .padding(0)
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 40, height: 30)
                            .padding(0)
                            .padding(.trailing, 15)
                            
                            Spacer()
                        }
                        .padding(0)
                        
                        
                        Text(account.name)
                        Spacer()
                        Text("\(account.balance, format: .currency(code: account.currency ?? "USD"))")
                            .padding(.trailing, 20)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable(action: {
            store.send(.startLoadingAccounts)
        })
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
        .onAppear {
            // TODO: In the real world, the initial account loading logic needs to be moved to an app-level logic
            // or be part of persistent storage layer logic.
            if store.accounts.isEmpty {
                store.send(.startLoadingAccounts)
            }
        }
    }
}

#Preview {
    AccountLookupView(store: Store(initialState: AccountLookupFeature.State(query: "")) { AccountLookupFeature() })
}
