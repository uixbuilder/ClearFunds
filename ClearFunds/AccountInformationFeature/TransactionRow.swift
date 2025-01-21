//
//  TransactionRow.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 18.01.2025.
//

import SwiftUI


struct TransactionRow: View {
    enum TransactionType: String, CaseIterable {
        case income
        case expense
        
        var color: Color {
            switch self {
            case .income:
                return .green
            case .expense:
                return .red
            }
        }
    }
    
    let transaction: Transaction
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    var transactionType: TransactionType { transaction.amount.value > 0 ? .income : .expense }
    var sharingText: String {
        "Transaction at \(transaction.processingDate, formatter: dateFormatter) " +
        "from: \(transaction.sender.name ?? "Unknown") - \(transaction.sender.accountNumber), " +
        "to: \(transaction.receiver.name ?? "Unknown") - \(transaction.receiver.accountNumber), " +
        "amount: \(transaction.amount.value.formatted(.currency(code: transaction.amount.currency)))"
    }
    
    var shareButton: some View {
        ShareLink(item: sharingText, subject: Text("Transaction Sharing")) {
            Image(systemName: "paperplane.fill")
        }
        .padding(.leading, 10)
        .frame(width: 40, height: 40)
    }

    var body: some View {
        HStack {
            // Icon or transaction type
            VStack {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .foregroundColor(transactionType.color)
                    .font(.title2)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.typeDescription)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let description = transaction.sender.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Text(transaction.sender.name ?? "Unknown Sender")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, 5)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.amount.value, format: .currency(code: transaction.amount.currency))
                    .font(.headline)
                    .foregroundColor(transactionType.color)
                
                Text(transaction.processingDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            shareButton
        }
    }
}

#Preview("Credit row", traits: .sizeThatFitsLayout) {
    TransactionRow(transaction: .creditPreviewData)
}


#Preview("Debit row", traits: .sizeThatFitsLayout) {
    TransactionRow(transaction: .debitPreviewData)
}

extension Transaction {
    fileprivate static let debitPreviewData = Transaction(
        amount: .init(value: -1.74, precision: 0, currency: "CZK"),
        type: "40900",
        dueDate: Date(),
        processingDate: Date(),
        sender: .init(
            accountNumber: "000000-0000000000",
            bankCode: "0800",
            iban: "CZ13 0800 0000 0029 0647 8309",
            specificSymbol: "0000000000",
            specificSymbolParty: "0000000000",
            variableSymbol: "0000000000",
            constantSymbol: "0000",
            name: "xxxxxxxxxxxx9126",
            description: "KORBEL ŠTĚPÁN"
        ),
        receiver: .init(
            accountNumber: "000000-2906478309",
            bankCode: "0800",
            iban: "CZ13 0800 0000 0029 0647 8309",
            name: "Julia Roberts"
        ),
        typeDescription: "Poplatky"
    )
    
    fileprivate static let creditPreviewData = Transaction(
            amount: .init(value: 2500.0, precision: 0, currency: "CZK"),
            type: "12345",
            dueDate: Date(),
            processingDate: Date(),
            sender: .init(
                accountNumber: "000000-0000001234",
                bankCode: "0800",
                iban: "CZ13 0800 0000 0012 3456 7890",
                specificSymbol: nil,
                specificSymbolParty: nil,
                variableSymbol: nil,
                constantSymbol: nil,
                name: "John Doe",
                description: "Salary Payment"
            ),
            receiver: .init(
                accountNumber: "000000-2906478309",
                bankCode: "0800",
                iban: "CZ13 0800 0000 0029 0647 8309",
                name: "Antonio Ramez"
            ),
            typeDescription: "Salary"
        )
}

private extension String.StringInterpolation {
    mutating func appendInterpolation(_ date: Date, formatter: DateFormatter) {
        appendLiteral(formatter.string(from: date))
    }
}
