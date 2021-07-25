//
//  File.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

protocol RequestDispatcherProtocol {

    init(environment: EnvironmentProtocol, networkSession: NetworkSessionProtocol)

    func execute(request: RequestProtocol, completion: @escaping (OperationResult) -> Void) -> URLSessionTask?
}
