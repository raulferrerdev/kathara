//
//  NetworkSessionProtocol.swift
//  
//
//  Created by RaulF on 25/7/21.
//

import Foundation

public protocol NetworkSessionProtocol {
    func dataTask(with request: URLRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask?
    
    func downloadTask(request: URLRequest,
                      progressHandler: ProgressHandler?,
                      completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask?
    
    func uploadTask(with request: URLRequest,
                    from fileURL: URL,
                    progressHandler: ProgressHandler?,
                    completion: @escaping (Data?, URLResponse?, Error?)-> Void) -> URLSessionUploadTask?
}
