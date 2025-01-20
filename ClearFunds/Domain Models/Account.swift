//
//  Account.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import Foundation


struct Account: Identifiable, Codable, Equatable {
    var id: String { accountNumber }
    let accountNumber: String
    let bankCode: String
    let transparencyFrom: Date
    let transparencyTo: Date
    let publicationTo: Date
    let actualizationDate: Date
    let balance: Double
    let currency: String?
    let name: String
    let iban: String
}

extension Account: PaginatableKeyed {
    static var collectionKey: String { "accounts" }
}
