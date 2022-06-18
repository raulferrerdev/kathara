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

class NetworkSession: NSObject {

    var session: URLSession!

    private typealias ProgressAndCompletionHandlers = (progress: ProgressHandler?, completion: ((URL?, URLResponse?, Error?) -> Void)?)

    private var taskToHandlersMap: [URLSessionTask : ProgressAndCompletionHandlers] = [:]

    public override convenience init() {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForResource = 30
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated

        self.init(configuration: sessionConfiguration, delegateQueue: queue)
    }

    public init(configuration: URLSessionConfiguration, delegateQueue: OperationQueue) {
        super.init()
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }

    private func set(handlers: ProgressAndCompletionHandlers?, for task: URLSessionTask) {
        taskToHandlersMap[task] = handlers
    }

    private func getHandlers(for task: URLSessionTask) -> ProgressAndCompletionHandlers? {
        return taskToHandlersMap[task]
    }

    deinit {
        session.invalidateAndCancel()
        session = nil
    }
}

extension NetworkSession: NetworkSessionProtocol {

    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask? {
        let dataTask = session.dataTask(with: request) { (data, response, error) in
            completionHandler(data, response, error)
        }
        return dataTask
    }

    func downloadTask(request: URLRequest, progressHandler: ProgressHandler? = nil, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask? {
        let downloadTask = session.downloadTask(with: request)
        set(handlers: (progressHandler, completionHandler), for: downloadTask)
        return downloadTask
    }

    func uploadTask(with request: URLRequest, from fileURL: URL, progressHandler: ProgressHandler? = nil, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask? {
        let uploadTask = session.uploadTask(with: request, fromFile: fileURL, completionHandler: { (data, urlResponse, error) in
            completion(data, urlResponse, error)
        })
        set(handlers: (progressHandler, nil), for: uploadTask)
        return uploadTask
    }
}

extension NetworkSession: URLSessionDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let handlers = getHandlers(for: task) else {
            return
        }

        let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            handlers.progress?(progress)
        }

        set(handlers: nil, for: task)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
            let handlers = getHandlers(for: downloadTask) else {
            return
        }

        DispatchQueue.main.async {
            handlers.completion?(nil, downloadTask.response, downloadTask.error)
        }

        set(handlers: nil, for: task)
    }
}



extension NetworkSession: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let handlers = getHandlers(for: downloadTask) else {
            return
        }

        DispatchQueue.main.async {
            handlers.completion?(location, downloadTask.response, downloadTask.error)
        }

        //  Remove the associated handlers.
        set(handlers: nil, for: downloadTask)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let handlers = getHandlers(for: downloadTask) else {
            return
        }

        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            handlers.progress?(progress)
        }
    }
}
