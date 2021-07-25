//
//  EnvironmentProtocol.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

protocol EnvironmentProtocol {
    var headers: ReaquestHeaders? { get }
    var baseURL: String { get }
}
