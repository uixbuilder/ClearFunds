//
//  Transaction.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 19.01.2025.
//

import Foundation


struct Transaction: Identifiable, Decodable, Equatable, Hashable {
    struct Amount: Decodable, Equatable, Hashable {
        let value: Double
        let precision: Int
        let currency: String
    }
    
    struct AccountDetails: Decodable, Equatable, Hashable {
        let accountNumber: String
        let bankCode: String
        let iban: String
        let specificSymbol: String?
        let specificSymbolParty: String?
        let variableSymbol: String?
        let constantSymbol: String?
        let name: String?
        let description: String?
        
        init(accountNumber: String,
             bankCode: String,
             iban: String,
             specificSymbol: String? = nil,
             specificSymbolParty: String? = nil,
             variableSymbol: String? = nil,
             constantSymbol: String? = nil,
             name: String? = nil,
             description: String? = nil)
        {
            self.accountNumber = accountNumber
            self.bankCode = bankCode
            self.iban = iban
            self.specificSymbol = specificSymbol
            self.specificSymbolParty = specificSymbolParty
            self.variableSymbol = variableSymbol
            self.constantSymbol = constantSymbol
            self.name = name
            self.description = description
        }
    }
    
    var id: String { sender.accountNumber + receiver.accountNumber +
                     "\(processingDate.timeIntervalSinceReferenceDate)" + "\(amount.value)" }
    
    let amount: Amount
    let type: String
    let dueDate: Date
    let processingDate: Date
    let sender: AccountDetails
    let receiver: AccountDetails
    let typeDescription: String
}

extension Transaction: PaginatableKeyed {
    static var collectionKey: String { "transactions" }
}

extension TransparencyDataClient.SortParameters.SortField {
    static let processingDate = "processingDate"
}
