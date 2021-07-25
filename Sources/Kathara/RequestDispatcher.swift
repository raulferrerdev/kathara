//
//  RequestDispatcher.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

public class RequestDispatcher: RequestDispatcherProtocol {

    private var environment: EnvironmentProtocol

    private var networkSession: NetworkSessionProtocol

    required init(environment: EnvironmentProtocol, networkSession: NetworkSessionProtocol) {
        self.environment = environment
        self.networkSession = networkSession
    }

    func execute(request: RequestProtocol, completion: @escaping (OperationResult) -> Void) -> URLSessionTask? {
        guard var urlRequest = request.urlRequest(with: environment) else {
            completion(.error(NetworkError.badRequest("Invalid URL for: \(request)"), nil))
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
        }

        task?.resume()

        return task
    }
}


private extension RequestDispatcher {

    func handleJsonTaskResponse(data: Data?, urlResponse: URLResponse?, error: Error?, completion: @escaping (OperationResult) -> Void) {
        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            completion(OperationResult.error(NetworkError.invalidResponse, nil))
            return
        }

        let result = verify(data: data, urlResponse: urlResponse, error: error)
        switch result {
        case .success(let data):
            let parseResult = parse(data: data as? Data)
            switch parseResult {
            case .success(let json):
                DispatchQueue.main.async {
                    completion(OperationResult.json(json, urlResponse))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(OperationResult.error(error, urlResponse))
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                completion(OperationResult.error(error, urlResponse))
            }
        }
    }

    
    func handleFileTaskResponse(fileUrl: URL?, urlResponse: URLResponse?, error: Error?, completion: @escaping (OperationResult) -> Void) {
        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            completion(OperationResult.error(NetworkError.invalidResponse, nil))
            return
        }

        let result = verify(data: fileUrl, urlResponse: urlResponse, error: error)
        switch result {
        case .success(let url):
            DispatchQueue.main.async {
                completion(OperationResult.file(url as? URL, urlResponse))
            }

        case .failure(let error):
            DispatchQueue.main.async {
                completion(OperationResult.error(error, urlResponse))
            }
        }
    }

    
    func parse(data: Data?) -> Result<Any, Error> {
        guard let data = data else {
            return .failure(NetworkError.invalidResponse)
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            return .success(json)
        } catch (let exception) {
            return .failure(NetworkError.parseError(exception.localizedDescription))
        }
    }

    
    func verify(data: Any?, urlResponse: HTTPURLResponse, error: Error?) -> Result<Any, Error> {
        switch urlResponse.statusCode {
        case 200...299:
            if let data = data {
                return .success(data)
            } else {
                return .failure(NetworkError.noData)
            }
        case 400...499:
            return .failure(NetworkError.badRequest(error?.localizedDescription))
        case 500...599:
            return .failure(NetworkError.serverError(error?.localizedDescription))
        default:
            return .failure(NetworkError.unknown)
        }
    }
}
