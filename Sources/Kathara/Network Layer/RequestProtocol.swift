//
//  RequestProtocol.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

typealias ReaquestHeaders = [String: String]
typealias RequestParameters = [String : Any?]
typealias ProgressHandler = (Float) -> Void

protocol RequestProtocol {
    var path: String { get }
    var method: RequestMethod { get }
    var headers: ReaquestHeaders? { get }
    var parameters: RequestParameters? { get }
    var requestType: RequestType { get }
    var responseType: ResponseType { get }
    var progressHandler: ProgressHandler? { get set }
}


extension RequestProtocol {

    public func urlRequest(with environment: EnvironmentProtocol) -> URLRequest? {
        guard let url = url(with: environment.baseURL) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = jsonBody

        return request
    }
}


private extension RequestProtocol {
    
    func url(with baseURL: String) -> URL? {
        guard var urlComponents = URLComponents(string: baseURL) else {
            return nil
        }
        urlComponents.path = urlComponents.path + path
        urlComponents.queryItems = queryItems

        return urlComponents.url
    }

    var queryItems: [URLQueryItem]? {
        guard method == .get,let parameters = parameters else {
            return nil
        }

        return parameters.map { (key: String, value: Any?) -> URLQueryItem in
            let valueString = String(describing: value)
            return URLQueryItem(name: key, value: valueString)
        }
    }

    var jsonBody: Data? {
        guard [.post, .put, .patch].contains(method), let parameters = parameters else {
            return nil
        }

        var jsonBody: Data?
        do {
            jsonBody = try JSONSerialization.data(withJSONObject: parameters,
                                                  options: .prettyPrinted)
        } catch {
            print(error)
        }
        
        return jsonBody
    }
}
