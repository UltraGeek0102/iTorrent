//
//  HttpDownloadListViewModel.swift
//  iTorrent
//
//  Manages the list of active/completed HTTP downloads.
//

import Combine
import Foundation
import MvvmFoundation

class HttpDownloadListViewModel: BaseViewModel {
    @Published var items: [HttpDownloadItemViewModel] = []

    private let service = HttpDownloadService.shared
    private var cancellables = Set<AnyCancellable>()

    required init() {
        super.init()
        service.$downloads
            .receive(on: DispatchQueue.main)
            .map { $0.map { HttpDownloadItemViewModel(item: $0) } }
            .assign(to: &$items)
    }

    func remove(at offsets: IndexSet) {
        offsets.forEach { index in
            let item = service.downloads[index]
            service.remove(item)
        }
    }

    func clearCompleted() {
        service.downloads
            .filter { $0.state == .completed }
            .forEach { service.remove($0) }
    }
}

// MARK: - Per-Item ViewModel

class HttpDownloadItemViewModel: NSObject, ObservableObject {
    let item: HttpDownloadItem
    private var cancellable: AnyCancellable?

    @Published var progress: Double = 0
    @Published var state: HttpDownloadItem.State = .pending
    @Published var bytesDownloaded: Int64 = 0
    @Published var totalBytes: Int64 = 0

    var fileName: String { item.fileName }
    var sourceURL: URL { item.url }

    init(item: HttpDownloadItem) {
        self.item = item
        super.init()

        item.$progress.assign(to: &$progress)
        item.$state.assign(to: &$state)
        item.$bytesDownloaded.assign(to: &$bytesDownloaded)
        item.$totalBytes.assign(to: &$totalBytes)
    }

    var progressText: String {
        let dl = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
        if totalBytes > 0 {
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(dl) / \(total)"
        }
        return dl
    }

    var stateText: String {
        switch state {
        case .pending: return "Waiting…"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    func togglePauseResume() {
        switch item.state {
        case .downloading: HttpDownloadService.shared.pause(item)
        case .paused: HttpDownloadService.shared.resume(item)
        default: break
        }
    }

    func cancel() {
        HttpDownloadService.shared.cancel(item)
    }
}
