//
//  HttpDownloadService.swift
//  iTorrent
//
//  Created for HTTP link downloading support.
//

import Combine
import Foundation
import UIKit

// MARK: - Download Item Model

public class HttpDownloadItem: NSObject, Identifiable, ObservableObject {
    public let id: UUID = .init()
    public let url: URL
    public let fileName: String
    public let destinationURL: URL

    @Published public var progress: Double = 0
    @Published public var state: State = .pending
    @Published public var bytesDownloaded: Int64 = 0
    @Published public var totalBytes: Int64 = 0
    @Published public var error: Error?

    public enum State {
        case pending
        case downloading
        case paused
        case completed
        case failed
    }

    var task: URLSessionDownloadTask?

    init(url: URL, destinationURL: URL) {
        self.url = url
        self.fileName = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        self.destinationURL = destinationURL
    }
}

// MARK: - HttpDownloadService

public class HttpDownloadService: NSObject {
    public static let shared = HttpDownloadService()

    @Published public var downloads: [HttpDownloadItem] = []

    private var session: URLSession!
    private var taskToItem: [URLSessionTask: HttpDownloadItem] = [:]
    private let queue = DispatchQueue(label: "com.itorrent.httpdownload", qos: .userInitiated)

    private static var downloadDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("HttpDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.itorrent.httpdownload.session")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Restore any in-progress tasks from previous session
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            // Background tasks that couldn't be matched are cancelled to keep state clean
            tasks.forEach { $0.cancel() }
        }
    }

    // MARK: - Public API

    @discardableResult
    public func startDownload(from url: URL, customFileName: String? = nil) -> HttpDownloadItem {
        let rawName = customFileName ?? url.lastPathComponent
        let fileName = rawName.isEmpty ? "download" : rawName
        let destination = Self.downloadDirectory.appendingPathComponent(fileName)

        let item = HttpDownloadItem(url: url, destinationURL: destination)
        let task = session.downloadTask(with: url)

        item.task = task
        item.state = .downloading

        queue.sync {
            taskToItem[task] = item
            DispatchQueue.main.async { [weak self] in
                self?.downloads.append(item)
            }
        }
        task.resume()
        return item
    }

    public func pause(_ item: HttpDownloadItem) {
        guard item.state == .downloading else { return }
        item.task?.suspend()
        DispatchQueue.main.async { item.state = .paused }
    }

    public func resume(_ item: HttpDownloadItem) {
        guard item.state == .paused else { return }
        item.task?.resume()
        DispatchQueue.main.async { item.state = .downloading }
    }

    public func cancel(_ item: HttpDownloadItem) {
        item.task?.cancel()
        queue.sync {
            if let task = item.task {
                taskToItem.removeValue(forKey: task)
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.downloads.removeAll { $0.id == item.id }
        }
    }

    public func remove(_ item: HttpDownloadItem) {
        cancel(item)
        try? FileManager.default.removeItem(at: item.destinationURL)
    }

    // MARK: - Helpers

    private func item(for task: URLSessionTask) -> HttpDownloadItem? {
        queue.sync { taskToItem[task] }
    }
}

// MARK: - URLSessionDownloadDelegate

extension HttpDownloadService: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let item = item(for: downloadTask) else { return }

        do {
            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: item.destinationURL.path) {
                try FileManager.default.removeItem(at: item.destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: item.destinationURL)
            DispatchQueue.main.async {
                item.state = .completed
                item.progress = 1.0
                NotificationCenter.default.post(name: .httpDownloadCompleted, object: item)
            }
        } catch {
            DispatchQueue.main.async {
                item.state = .failed
                item.error = error
                NotificationCenter.default.post(name: .httpDownloadFailed, object: item)
            }
        }

        queue.sync { taskToItem.removeValue(forKey: downloadTask) }
    }

    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        guard let item = item(for: downloadTask) else { return }
        DispatchQueue.main.async {
            item.bytesDownloaded = totalBytesWritten
            item.totalBytes = totalBytesExpectedToWrite
            item.progress = totalBytesExpectedToWrite > 0
                ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                : 0
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let item = item(for: task) else { return }
        // Ignore cancellation errors (user-initiated)
        let nsErr = error as NSError
        guard nsErr.code != NSURLErrorCancelled else { return }

        DispatchQueue.main.async {
            item.state = .failed
            item.error = error
            NotificationCenter.default.post(name: .httpDownloadFailed, object: item)
        }
        queue.sync { taskToItem.removeValue(forKey: task) }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let httpDownloadCompleted = Notification.Name("com.itorrent.httpDownloadCompleted")
    static let httpDownloadFailed = Notification.Name("com.itorrent.httpDownloadFailed")
}
