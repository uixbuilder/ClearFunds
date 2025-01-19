//
//  TransactionsChartView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 18.01.2025.
//

import SwiftUI
import Charts
import ComposableArchitecture


struct TransactionsChartView: View {
    let transactions: IdentifiedArrayOf<Transaction>
    
    let ruleStyle = StrokeStyle(
        lineWidth: 1,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 5,
        dash: [10,10],
        dashPhase: 1)
    
    var body: some View {
        Chart(transactions) { transaction in
            BarPlot(
                transactions,
                x: .value("Date", transaction.processingDate),
                y: .value("Amount", abs(transaction.amount.value))
            )
            .foregroundStyle(by: .value("Type", transaction.amount.value > 0 ? "Credit" : "Debit"))
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(anchor: .leading).offset(x: 10)
            }
        }
        .chartForegroundStyleScale([
            "Credit" : .green.opacity(0.6),
            "Debit": .red.opacity(0.6)
        ])
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    TransactionsChartView(transactions: .chartPreviewData)
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .frame(height: 300)
        .cornerRadius(20)
}

extension IdentifiedArray where Element == Transaction, ID == String {
    static var chartPreviewData: Self {
        let result = (1...100)
            .map { (amount: Int.random(in: -1000...1000),
                    date: Date(timeIntervalSinceReferenceDate: TimeInterval($0 * 10000000))) }
            .map {
                Transaction(
                    amount: .init(value: Double($0.amount), precision: 0, currency: "CZK"),
                    type: "40900",
                    dueDate: Date(),
                    processingDate: $0.date,
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
                        name: "Jiří Novák"
                    ),
                    typeDescription: "Poplatky"
                )
            }
        return IdentifiedArray(uniqueElements: result)
    }
}

