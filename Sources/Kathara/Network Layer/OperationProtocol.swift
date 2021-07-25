//
//  OperationProtocol.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

protocol OperationProtocol {
    associatedtype Output

    var request: RequestProtocol { get }

    func execute(in requestDispatcher: RequestDispatcherProtocol, completion: @escaping (Output) -> Void) ->  Void

    func cancel() -> Void
}
