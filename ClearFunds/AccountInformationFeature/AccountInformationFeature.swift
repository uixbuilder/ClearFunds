//
//  AccountInformationFeature.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 18.01.2025.
//

import Foundation
import ComposableArchitecture


@Reducer
struct AccountInformationFeature {
    @ObservableState
    struct State: Equatable {
        let account: Account
        var transactions: IdentifiedArrayOf<Transaction> = []
        var isFavorite: Bool = false
        var isDataLoading: Bool = false
    }
    
    enum Action {
        case startLoadingTransactions
        case toggleFavoriteButtonTapped
        case dataResponse(Result<PaginatedResponse<Transaction>, Error>)
        case delegate(Delegate)
        @CasePathable
        enum Alert {
            case retryDetailsLoading
        }
        @CasePathable
        enum Delegate {
            case toggleFavoriteState(id: Account.ID)
        }
    }
}
