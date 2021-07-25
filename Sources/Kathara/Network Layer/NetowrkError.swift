//
//  NetworkError.swift
//  
//
//  Created by RaulF on 25/7/21.
//

enum NetworkError: Error {
    case noData
    case invalidResponse
    case badRequest(String?)
    case serverError(String?)
    case parseError(String?)
    case unknown
}
