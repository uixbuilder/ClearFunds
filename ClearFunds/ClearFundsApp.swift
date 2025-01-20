//
//  ClearFundsApp.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 16.01.2025.
//

import SwiftUI
import ComposableArchitecture


@main
struct ClearFundsApp: App {
    let store = Store(initialState: .init()) { MainScreenRouter() }
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
