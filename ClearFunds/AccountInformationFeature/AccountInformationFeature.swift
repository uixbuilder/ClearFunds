//
//  AccountInformationFeature.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 18.01.2025.
//

import Foundation
import ComposableArchitecture


@Reducer
struct AccountInformationFeature: Loggable {
    @ObservableState
    struct State: Equatable {
        let account: Account
        var transactions: IdentifiedArrayOf<Transaction> = []
        var isDataLoading: Bool = false
    }
    @CasePathable
    enum Action: Equatable {
        case startLoadingTransactions
        case nextPageResponse(Result<PaginatedResponse<Transaction>, TransparencyDataClient.Error>)
        case delegate(Delegate)
        case resumeLoadingTransactions
        @CasePathable
        enum Delegate: Equatable {
            case transactionLoadingFailed(TransparencyDataClient.Error)
        }
    }
    
    let cachingPageSize: Int = 5
    
    @Dependency(\.dataProvider) var dataProvider
    
    private enum CancelID {
        case pageLoading
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startLoadingTransactions:
                state.isDataLoading = true
                state.transactions = []
                return makeLoadPageEffect(state.account.id, page: 0)
                
            case .nextPageResponse(.success(let response)):
                state.transactions.append(contentsOf: response.items)
                if state.transactions.count == 0 && response.pageNumber == 0 {
                    // Received an empty response on the first page.
                    state.isDataLoading = false
                    return .none
                }
                
                if (response.nextPage < response.pageCount && response.nextPage != 0) {
                    // There are more pages to load.
                    return makeLoadPageEffect(state.account.id, page: response.nextPage)
                }
                
                state.isDataLoading = false
                return .none
                
            case .nextPageResponse(.failure(let error)):
                state.isDataLoading = false
                return .run { send in
                    await send(.delegate(.transactionLoadingFailed(error)))
                }
                
            case .resumeLoadingTransactions:
                state.isDataLoading = true
                let nextPageIndex = state.transactions.count / cachingPageSize
                return makeLoadPageEffect(state.account.id, page: nextPageIndex)
                
            case .delegate:
                return .none
            }
        }
    }
    
    private func makeLoadPageEffect(_ accountId: String, page: Int) -> Effect<AccountInformationFeature.Action> {
        .run { send in
            await send(.nextPageResponse(Result {
                try await dataProvider.transactions(
                    accountId: accountId,
                    filter: nil,
                    sort: [.init(sortField: .processingDate, order: .desc)],
                    pagination: .init(page: page, pageSize: cachingPageSize))
            }.mapError({ error in
                if let clientError = error as? TransparencyDataClient.Error {
                    return clientError
                } else {
                    logger.error("Error type mismatch while loading accounts: \(error)")
                    return TransparencyDataClient.Error.clientInternal(error.localizedDescription)
                }
            })))
        }
        .cancellable(id: CancelID.pageLoading, cancelInFlight: true)
    }
}
