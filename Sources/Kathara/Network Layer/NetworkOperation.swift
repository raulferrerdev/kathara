//
//  File.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

public class NetworkOperation: OperationProtocol {
    typealias Output = OperationResult

    private var task: URLSessionTask?

    internal var request: RequestProtocol

    init(_ request: RequestProtocol) {
        self.request = request
    }

    func cancel() {
        task?.cancel()
    }

    func execute(in requestDispatcher: RequestDispatcherProtocol, completion: @escaping (OperationResult) -> Void) {
        task = requestDispatcher.execute(request: request, completion: { result in
            completion(result)
        })
    }
}
