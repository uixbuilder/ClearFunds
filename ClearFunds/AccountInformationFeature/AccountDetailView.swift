//
//  AccountDetailView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 19.01.2025.
//

import SwiftUI
import ComposableArchitecture


struct AccountDetailView: View {
    @Bindable var store: StoreOf<AccountInformationFeature>
    
    var header: some View {
        VStack {
            HStack {
                VStack(alignment: .trailing, spacing: 20) {
                    Group {
                        Text("Name:")
                        Text("Account Number:")
                        Text("IBAN:")
                        Text("Balance:")
                    }
                    .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text(store.account.name)
                        .fontWeight(.semibold)
                    HStack {
                        Text(store.account.accountNumber)
                            .textSelection(.enabled)
                        Image(systemName: "document.on.document")
                    }
                    HStack {
                        Text(store.account.iban)
                            .textSelection(.enabled)
                        Image(systemName: "document.on.document")
                    }
                    Text(store.account.balance.description)
                }
                Spacer()
            }
            
            loadingProgress
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    var loadingProgress: some View {
        HStack {
            if store.state.isDataLoading {
                ProgressView()
                Text("Loading transactions...")
            }
            else {
                Group {
                    Image(systemName: "checkmark.icloud")
                    Text("\(store.state.transactions.count) transactions is loaded")
                }
                .foregroundStyle(.green)
            }
        }
        .frame(height: 20)
    }
    
    var chartView: some View {
        VStack {
            Text("Movements by month")
            if store.state.transactions.isEmpty {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemGroupedBackground))
            }
            else {
                TransactionsChartView(transactions: store.transactions)
                    .padding(EdgeInsets(top: 15, leading: 30, bottom: 10, trailing: 15))
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(20)
            }
        }
    }
    
    @ViewBuilder
    var content: some View {
        if store.state.transactions.isEmpty {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGroupedBackground))
        }
        else {
            List(store.transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
            .scrollIndicatorsFlash(onAppear: true)
            .listStyle(.insetGrouped)
            .contentMargins(12)
            .overlay(content: {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(lineWidth: 24)
                    .fill(Color(UIColor.systemGroupedBackground))
            })
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                VStack {
                    header
                    Spacer(minLength: 20)
                    content
                    chartView
                }
            }
            else {
                HStack {
                    VStack {
                        header
                        chartView
                    }
                    content
                }
            }
        }
        .padding()
        .onAppear {
            store.send(.startLoadingTransactions)
        }
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(
            store: Store(initialState: AccountInformationFeature.State(
                account: .previewAccount,
                isDataLoading: true)) {
                    AccountInformationFeature()
                })
    }
}

extension Account {
    fileprivate static let previewAccount = Account(
        accountNumber: "12345678901234567890",
        bankCode: "1234567890",
        transparencyFrom: Date(),
        transparencyTo: Date(),
        publicationTo: Date(),
        actualizationDate: Date(),
        balance: 12345.67,
        currency: "USD",
        name: "Some Long Name",
        iban: "CZ99999999999999999999999"
    )
}
