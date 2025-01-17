//
//  AccountDetailView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 17.01.2025.
//

import SwiftUI


struct AccountDetailView: View {
    let account: Account
    var body: some View {
        HStack {
            VStack(alignment: .trailing) {
                Group {
                    Text("Name:")
                    Text("Account Number:")
                    Text("IBAN:")
                    Text("Balance:")
                }
                .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text(account.name)
                    .fontWeight(.semibold)
                Text(account.accountNumber)
                Text(account.iban)
                Text(account.balance.description)
            }
        }
    }
}

#Preview {
    AccountDetailView(account: .init(
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
    ))
}
