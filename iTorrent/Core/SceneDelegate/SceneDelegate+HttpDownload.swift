//
//  SceneDelegate+HttpDownload.swift
//  iTorrent
//
//  Extends URL processing to intercept HTTP links that are NOT .torrent files
//  and route them to HttpDownloadService instead.
//
//  INTEGRATION:
//  In SceneDelegate+URLProcessing.swift, update processURL(_:) to call
//  tryStartHttpDownload(with:) AFTER tryOpenRemoteAddTorrent:
//
//      func processURL(_ url: URL) {
//          Task {
//              if tryOpenTorrentDetails(with: url) { return }
//              if tryOpenAddTorrent(with: url) { return }
//              if tryOpenAddMagnet(with: url) { return }
//              if await tryOpenRemoteAddTorrent(with: url) { return }
//              tryStartHttpDownload(with: url)   // <-- ADD THIS LINE
//          }
//      }
//

import UIKit

extension SceneDelegate {

    func tryStartHttpDownload(with url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return }

        let ext = url.pathExtension.lowercased()
        guard ext != "torrent" else { return }

        guard let rootVC = window?.rootViewController?.topPresented else { return }

        let fileName = url.lastPathComponent.isEmpty ? "file" : url.lastPathComponent
        let alert = UIAlertController(
            title: "Download File?",
            message: "Do you want to download \(fileName) from \(url.host ?? url.absoluteString)?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Download", style: .default) { _ in
            let item = HttpDownloadService.shared.startDownload(from: url)
            let confirm = UIAlertController(
                title: "Download Started",
                message: item.fileName,
                preferredStyle: .alert
            )
            confirm.addAction(UIAlertAction(title: "OK", style: .cancel))
            rootVC.present(confirm, animated: true)
        })
        rootVC.present(alert, animated: true)
    }
}
