//
//  HttpDownloadService.swift
//  iTorrent
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
    private var taskToItem: [Int: HttpDownloadItem] = [:]  // keyed by taskIdentifier (Int) — safe across threads

    private static var downloadDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("HttpDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override init() {
        super.init()
        // Use a default (non-background) session to avoid background session restrictions
        // when app is not properly signed with background modes entitlement
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
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

        // All on main thread — delegate queue is also main
        taskToItem[task.taskIdentifier] = item
        downloads.append(item)

        task.resume()
        return item
    }

    public func pause(_ item: HttpDownloadItem) {
        guard item.state == .downloading else { return }
        item.task?.suspend()
        item.state = .paused
    }

    public func resume(_ item: HttpDownloadItem) {
        guard item.state == .paused else { return }
        item.task?.resume()
        item.state = .downloading
    }

    public func cancel(_ item: HttpDownloadItem) {
        item.task?.cancel()
        taskToItem.removeValue(forKey: item.task?.taskIdentifier ?? -1)
        downloads.removeAll { $0.id == item.id }
    }

    public func remove(_ item: HttpDownloadItem) {
        cancel(item)
        try? FileManager.default.removeItem(at: item.destinationURL)
    }
}

// MARK: - URLSessionDownloadDelegate

extension HttpDownloadService: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let item = taskToItem[downloadTask.taskIdentifier] else { return }

        do {
            if FileManager.default.fileExists(atPath: item.destinationURL.path) {
                try FileManager.default.removeItem(at: item.destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: item.destinationURL)
            item.state = .completed
            item.progress = 1.0
            NotificationCenter.default.post(name: .httpDownloadCompleted, object: item)
        } catch {
            item.state = .failed
            item.error = error
            NotificationCenter.default.post(name: .httpDownloadFailed, object: item)
        }

        taskToItem.removeValue(forKey: downloadTask.taskIdentifier)
    }

    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        guard let item = taskToItem[downloadTask.taskIdentifier] else { return }
        item.bytesDownloaded = totalBytesWritten
        item.totalBytes = totalBytesExpectedToWrite
        item.progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        guard let item = taskToItem[task.taskIdentifier] else { return }

        let nsErr = error as NSError
        guard nsErr.code != NSURLErrorCancelled else { return }

        item.state = .failed
        item.error = error
        NotificationCenter.default.post(name: .httpDownloadFailed, object: item)
        taskToItem.removeValue(forKey: task.taskIdentifier)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let httpDownloadCompleted = Notification.Name("com.itorrent.httpDownloadCompleted")
    static let httpDownloadFailed = Notification.Name("com.itorrent.httpDownloadFailed")
}
