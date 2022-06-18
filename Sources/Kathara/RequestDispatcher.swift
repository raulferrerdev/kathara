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

class RequestDispatcher: RequestDispatcherProtocol {

    private var environment: EnvironmentProtocol

    private var networkSession: NetworkSessionProtocol

    required init(environment: EnvironmentProtocol, networkSession: NetworkSessionProtocol) {
        self.environment = environment
        self.networkSession = networkSession
    }

    func execute(request: RequestProtocol, completion: @escaping (NetworkOperationResult) -> Void) -> URLSessionTask? {
       
        guard var urlRequest = request.urlRequest(with: environment) else {
            completion(.error(NetworkError.badRequest, nil))
            return nil
        }
        
        environment.headers?.forEach({ (key: String, value: String) in
            urlRequest.addValue(value, forHTTPHeaderField: key)
        })

        var task: URLSessionTask?
        switch request.requestType {
        case .data:
            task = networkSession.dataTask(with: urlRequest, completionHandler: { (data, urlResponse, error) in
                self.handleJsonTaskResponse(data: data, urlResponse: urlResponse, error: error, completion: completion)
            })
        case .download:
            task = networkSession.downloadTask(request: urlRequest, progressHandler: request.progressHandler, completionHandler: { (fileUrl, urlResponse, error) in
                self.handleFileTaskResponse(fileUrl: fileUrl, urlResponse: urlResponse, error: error, completion: completion)
            })
            break
        case .upload:
            task = networkSession.uploadTask(with: urlRequest, from: URL(fileURLWithPath: ""), progressHandler: request.progressHandler, completion: { (data, urlResponse, error) in
                self.handleJsonTaskResponse(data: data, urlResponse: urlResponse, error: error, completion: completion)
            })
            break
        case .validation:
            task = networkSession.dataTask(with: urlRequest, completionHandler: { (data, urlResponse, error) in
                self.handleValidationTaskResponse(urlResponse: urlResponse, error: error, completion: completion)
            })
        }
        
        task?.resume()

        return task
    }

    private func handleJsonTaskResponse(data: Data?, urlResponse: URLResponse?, error: Error?, completion: @escaping (NetworkOperationResult) -> Void) {
        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            completion(NetworkOperationResult.error(NetworkError.invalidResponse, nil))
            return
        }
                
        let result = verify(data: data, urlResponse: urlResponse, error: error)
        switch result {
        case .success(let data):
            let parseResult = parse(data: data as? Data)
            switch parseResult {
            case .success(let json):
                if let json = json as? Dictionary<String, Any> {
                    var newJson = Dictionary<String, Any>()
                    for key in json.keys {
                        if let array = json[key] as? Array<Any> {
                            newJson[key] = array.isEmpty ? nil : json[key]
                        } else {
                            newJson[key] = json[key]
                        }
                    }
                    DispatchQueue.main.async {
                        completion(NetworkOperationResult.json(newJson, urlResponse))
                    }
                } else if let json = json as? Array<Dictionary<String, Any>> {
                    var newJsonArray = Array<Dictionary<String, Any>>()
                    for element in json {
                        var newJson = Dictionary<String, Any>()
                        for key in element.keys {
                            if let array = element[key] as? Array<Any> {
                                newJson[key] = array.isEmpty ? nil : element[key]
                            } else {
                                newJson[key] = element[key]
                            }
                        }
                        
                        newJsonArray.append(newJson)
                    }
                    DispatchQueue.main.async {
                        completion(NetworkOperationResult.json(newJsonArray, urlResponse))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(NetworkOperationResult.error(error, urlResponse))
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                completion(NetworkOperationResult.error(error, urlResponse))
            }
        }
    }
    
    private func handleValidationTaskResponse(urlResponse: URLResponse?, error: Error?, completion: @escaping (NetworkOperationResult) -> Void) {
        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            completion(NetworkOperationResult.error(NetworkError.invalidResponse, nil))
            return
        }
                
        if urlResponse.statusCode >= 200 && urlResponse.statusCode < 300 {
            DispatchQueue.main.async {
                completion(NetworkOperationResult.json(true, urlResponse))
            }
        } else {
            DispatchQueue.main.async {
                completion(NetworkOperationResult.error(error, urlResponse))
            }
        }
    }

    private func handleFileTaskResponse(fileUrl: URL?, urlResponse: URLResponse?, error: Error?, completion: @escaping (NetworkOperationResult) -> Void) {
        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            completion(NetworkOperationResult.error(NetworkError.invalidResponse, nil))
            return
        }

        let result = verify(data: fileUrl, urlResponse: urlResponse, error: error)
        switch result {
        case .success(let url):
            DispatchQueue.main.async {
                completion(NetworkOperationResult.file(url as? URL, urlResponse))
            }

        case .failure(let error):
            DispatchQueue.main.async {
                completion(NetworkOperationResult.error(error, urlResponse))
            }
        }
    }

    private func parse(data: Data?) -> Result<Any, Error> {
        guard let data = data else {
            return .failure(NetworkError.invalidResponse)
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            return .success(json)
        } catch {
            return .failure(NetworkError.parseError)
        }
    }

    private func verify(data: Any?, urlResponse: HTTPURLResponse, error: Error?) -> Result<Any, Error> {
        switch urlResponse.statusCode {
        case 200...299:
            if let data = data {
                return .success(data)
            } else {
                return .failure(NetworkError.noData)
            }
        case 400...499:
            if let data = data {
                return .success(data)
            } else {
                return .failure(NetworkError.badRequest)
            }
        case 500...599:
            return .failure(NetworkError.serverError)
        default:
            return .failure(NetworkError.unknown)
        }
    }
}
