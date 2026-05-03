//
//  TorrentListViewController+HttpDownload.swift
//  iTorrent
//

import Combine
import UIKit
import ObjectiveC

extension TorrentListViewController {

    // MARK: - Add menu action

    func makeHttpDownloadAction() -> UIAction {
        UIAction(
            title: "HTTP Link",
            image: UIImage(systemName: "arrow.down.to.line.circle")
        ) { [unowned self] _ in
            present(makeHttpLinkAlert(), animated: true)
        }
    }

    // MARK: - Alert

    func makeHttpLinkAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: "Download from HTTP",
            message: "Enter a direct download link (http:// or https://)",
            preferredStyle: .alert
        )

        alert.addTextField { tf in
            tf.placeholder = "https://example.com/file.zip"
            tf.keyboardType = .URL
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no

            if let clip = UIPasteboard.general.string,
               clip.lowercased().hasPrefix("http"),
               URL(string: clip) != nil {
                tf.text = clip
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        let download = UIAlertAction(title: "Download", style: .default) { [weak self, weak alert] _ in
            guard
                let self,
                let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty,
                let url = URL(string: text),
                url.scheme == "http" || url.scheme == "https"
            else {
                self?.showHttpLinkError()
                return
            }

            HttpDownloadService.shared.startDownload(from: url)
            self.showDownloadStartedBanner()
        }
        alert.addAction(download)
        alert.preferredAction = download
        return alert
    }

    // MARK: - Feedback

    private func showHttpLinkError() {
        let err = UIAlertController(
            title: "Invalid Link",
            message: "Please enter a valid http:// or https:// URL.",
            preferredStyle: .alert
        )
        err.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(err, animated: true)
    }

    private func showDownloadStartedBanner() {
        let banner = UIAlertController(
            title: "Download Started",
            message: "Track progress in the main list",
            preferredStyle: .alert
        )
        banner.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(banner, animated: true)
    }
}
