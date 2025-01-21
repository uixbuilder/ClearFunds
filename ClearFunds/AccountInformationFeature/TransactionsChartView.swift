//
//  TransactionsChartView.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 18.01.2025.
//

import SwiftUI
import Charts
import ComposableArchitecture


struct ChartBarData {
    let date: Date
    let debit: Double
    let credit: Double
}

struct TransactionsChartView: View {
    let transactions: IdentifiedArrayOf<Transaction>
    @State var chartData = [ChartBarData]()
    
    var body: some View {
        Task {
            // TODO: For bigger sets of the data, this approach is wasteful.
            // Right now, it is just used as a showcase for pagination functionality.
            // Probably after experimenting on the real datasets, grouping could be moved in a separate Chart reducer.
            chartData = groupTransactionsToChartData()
        }
        return Chart(chartData, id: \.date) { entry in
            BarMark(
                x: .value("Date", entry.date),
                y: .value("Debit", entry.debit)
            )
            .foregroundStyle(.red)
            
            BarMark(
                x: .value("Date", entry.date),
                y: .value("Credit", entry.credit)
            )
            .foregroundStyle(.green)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(anchor: .leading).offset(x: 10)
            }
        }
    }
    
    private func groupTransactionsToChartData() -> [ChartBarData] {
        let calendar = Calendar.current
        
        // Group transactions by month and year
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.dateComponents([.year, .month], from: transaction.processingDate)
        }
        
        // Calculate sums for debit and credit
        return grouped.compactMap { (key, transactions) in
            guard let date = calendar.date(from: key) else {
                return nil
            }
            
            let totalDebit = transactions
                .filter { $0.amount.value < 0 }
                .reduce(0) { $0 + $1.amount.value }
            
            let totalCredit = transactions
                .filter { $0.amount.value > 0 }
                .reduce(0) { $0 + $1.amount.value }
            
            return ChartBarData(date: date, debit: totalDebit, credit: totalCredit)
        }
        .sorted { $0.date < $1.date } // Sort by month
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
        let result = (1...60)
            .map { (amount: Int.random(in: -1000...1500),
                    date: Date(timeIntervalSinceReferenceDate: TimeInterval($0 * 800000))) }
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

