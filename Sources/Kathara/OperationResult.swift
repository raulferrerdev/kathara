//
//  File.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

public enum OperationResult {
    case json(_ : Any?, _ : HTTPURLResponse?)
    case file(_ : URL?, _ : HTTPURLResponse?)
    case error(_ : Error?, _ : HTTPURLResponse?)
}
