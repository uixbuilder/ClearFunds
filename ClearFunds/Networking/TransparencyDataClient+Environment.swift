//
//  TransparencyDataClient+Environment.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 10.03.2025.
//

import Foundation


extension TransparencyDataClient.Environment {
    private static let apiBaseUrl = "https://webapi.developers.erstegroup.com/api/csas/public/sandbox/v3"
    
    static func basedOnEnvironmentKey() throws(TransparencyDataClient.Error) -> Self {
        guard let apiKey = ProcessInfo.processInfo.environment["WEB-API-key"] else {
            throw .clientMisconfiguredError
        }
        
        guard let baseURL = URL(string: apiBaseUrl) else { throw .clientMisconfiguredError }

        return Self(apiKey: apiKey, baseURL: baseURL)
    }
    
    static func basedOnApiKey(_ apiKey: String) throws(TransparencyDataClient.Error) -> Self {
        guard let baseURL = URL(string: apiBaseUrl) else { throw .clientMisconfiguredError }
        
        return Self(apiKey: apiKey, baseURL: baseURL)
    }
}
