//  MIT License
//
//  Copyright (c) 2022 Raúl Ferrer García
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

typealias ReaquestHeaders = [String: String]
typealias RequestParameters = Any?
typealias ProgressHandler = (Float) -> Void

protocol RequestProtocol {
    var path: String { get }
    var method: RequestMethod { get }
    var headers: ReaquestHeaders? { get }
    var parameters: RequestParameters? { get }
    var requestType: RequestType { get }
    var responseType: ResponseType { get }
    var progressHandler: ProgressHandler? { get set }
    var requestBodyFormat: RequestBodyFormat? { get }
}

extension RequestProtocol {

    public func urlRequest(with environment: EnvironmentProtocol) -> URLRequest? {
        var request: URLRequest!
        if environment.baseURL.isEmpty {
            request = URLRequest(url: URL(string: path)!)
        } else {
            guard let url = url(with: environment.baseURL) else {
                return nil
            }
            request = URLRequest(url: url)
        }

        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = jsonBody

        return request
    }

    private func url(with baseURL: String) -> URL? {
        guard var urlComponents = URLComponents(string: baseURL) else {
            return nil
        }
        urlComponents.path = urlComponents.path + path
        urlComponents.queryItems = queryItems

        return urlComponents.url
    }

    private var queryItems: [URLQueryItem]? {
        guard method == .get, let parameters = parameters, let items = parameters as? [String : Any?] else {
            return nil
        }

        return items.map { (key: String, value: Any?) -> URLQueryItem in
            let valueString = String(describing: value)
            return URLQueryItem(name: key, value: valueString)
        }
    }
    
    private var jsonBody: Data? {
        guard [.post, .put, .patch].contains(method), let parameters = parameters else {
            return nil
        }
        
        var jsonBody: Data?
        
        if requestBodyFormat == .url {
            guard let items = parameters as? [String : Any?] else { return nil }
            var postString = ""
            for key in items.keys {
                let param = items[key] as! String
                postString += key + "=" + param + "&"
            }
            
            postString.removeLast()
            jsonBody = postString.data(using: .utf8)
        } else {
            guard let items = parameters else { return nil }
            do {
                jsonBody = try JSONSerialization.data(withJSONObject: items,
                                                      options: .prettyPrinted)
            } catch {}
        }
        
        return jsonBody
    }
}

