//
//  File.swift
//  
//
//  Created by Raúl Ferrer on 18/6/22.
//

import Foundation


public protocol ParseNetworkResultDelegate: AnyObject {
    func parseNetworkResult<T: Codable>(result: NetworkOperationResult,
                                        into model: T.Type) throws -> (T?, HTTPURLResponse)
}


public class JSONToObject: ParseNetworkResultDelegate {
    
    public func parseNetworkResult<T: Codable>(result: NetworkOperationResult,
                                               into model: T.Type) throws -> (T?, HTTPURLResponse) {
        
        guard case .json(let json, let response) = result else {
            throw NetworkError.serverError
        }
        
        guard let json = json,
              let jsonData = try? JSONSerialization.data(withJSONObject: json,
                                                         options: JSONSerialization.WritingOptions.prettyPrinted) as Data,
              let response = response else {
            throw NetworkError.serverError
        }
        
        switch response.statusCode {
            case 100...199:
                throw NetworkError.info
            case 300...399:
                throw NetworkError.redirection
            case 400...499:
                throw NetworkError.clientError
            case 500...599:
                throw NetworkError.clientError
            default:
                break
        }
        
        let decoder = JSONDecoder()
        do {
            let object = try decoder.decode(model.self, from: jsonData)
            return (object, response)
        } catch {
            throw NetworkError.parseError
        }
    }
}
