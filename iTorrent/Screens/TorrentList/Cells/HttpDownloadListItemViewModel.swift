//
//  HttpDownloadListItemViewModel.swift
//  iTorrent
//

import Combine
import MvvmFoundation
import UIKit

class HttpDownloadListItemViewModel: BaseViewModel, MvvmSelectableProtocol, ObservableObject, Identifiable {
    let item: HttpDownloadItem
    var selectAction: (() -> Void)?
    var id: UUID { item.id }

    @Published var title: String = ""
    @Published var progressText: String = ""
    @Published var statusText: String = ""
    @Published var progress: Double = 0

    init(item: HttpDownloadItem) {
        self.item = item
        super.init()
        updateUI()

        disposeBag.bind {
            item.$progress
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.updateUI() }

            item.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.updateUI() }

            item.$bytesDownloaded
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.updateUI() }
        }
    }

    required init() { fatalError("Use init(item:)") }

    override func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func cancelDownload() {
        HttpDownloadService.shared.cancel(item)
    }

    func togglePauseResume() {
        switch item.state {
        case .downloading: HttpDownloadService.shared.pause(item)
        case .paused: HttpDownloadService.shared.resume(item)
        default: break
        }
    }
}

private extension HttpDownloadListItemViewModel {
    func updateUI() {
        title = item.fileName

        let dl = ByteCountFormatter.string(fromByteCount: item.bytesDownloaded, countStyle: .file)
        let total = item.totalBytes > 0
            ? ByteCountFormatter.string(fromByteCount: item.totalBytes, countStyle: .file)
            : "?"
        let pct = item.totalBytes > 0
            ? String(format: "%.2f", item.progress * 100) + "%"
            : "..."

        progressText = "\(dl) of \(total) (\(pct))"

        switch item.state {
        case .pending:     statusText = "Waiting…"
        case .downloading: statusText = "Downloading (HTTP)"
        case .paused:      statusText = "Paused"
        case .completed:   statusText = "Completed"
        case .failed:      statusText = "Failed — \(item.error?.localizedDescription ?? "unknown error")"
        }

        progress = item.progress
    }
}
