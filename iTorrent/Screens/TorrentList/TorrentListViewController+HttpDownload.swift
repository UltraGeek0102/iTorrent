//
//  TorrentListViewController+HttpDownload.swift
//  iTorrent
//
//  Add this file alongside TorrentListViewController.swift.
//
//  HOW TO INTEGRATE:
//  1. In TorrentListViewController.swift, inside the addButton.menu children array,
//     add makeHttpDownloadAction() as the last item:
//
//      addButton.menu = UIMenu(title: %"list.add.title", children: [
//          ...,
//          makeHttpDownloadAction(),
//      ])
//
//  2. In viewDidLoad, after toolbar setup:
//
//      let downloadsBtn = makeDownloadsButton()
//      navigationItem.rightBarButtonItems = (navigationItem.rightBarButtonItems ?? []) + [downloadsBtn]
//

import Combine
import UIKit
import ObjectiveC

extension TorrentListViewController {

    // MARK: - Downloads Nav Button

    

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

            let item = HttpDownloadService.shared.startDownload(from: url)
            self.showDownloadStartedToast(for: item)
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

    private func showDownloadStartedToast(for item: HttpDownloadItem) {
        let banner = UIAlertController(
            title: "Download Started",
            message: item.fileName,
            preferredStyle: .alert
        )
        banner.addAction(UIAlertAction(title: "View Downloads", style: .default) { [weak self] _ in
            self?.openHttpDownloads()
        })
        banner.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(banner, animated: true)
    }
}

// MARK: - Cancellable storage

private var downloadCancellablesKey: UInt8 = 0

extension TorrentListViewController {
    var downloadCancellables: Set<AnyCancellable> {
        get {
            if let existing = objc_getAssociatedObject(self, &downloadCancellablesKey) as? Set<AnyCancellable> {
                return existing
            }
            let new = Set<AnyCancellable>()
            objc_setAssociatedObject(self, &downloadCancellablesKey, new, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return new
        }
        set {
            objc_setAssociatedObject(self, &downloadCancellablesKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - UIBarButtonItem badge

extension UIBarButtonItem {
    func setBadgeValue(_ value: String?) {
        guard let view = self.value(forKey: "view") as? UIView else { return }
        view.subviews.first(where: { $0.accessibilityIdentifier == "badge" })?.removeFromSuperview()
        guard let value else { return }

        let badge = UILabel()
        badge.accessibilityIdentifier = "badge"
        badge.text = value
        badge.textColor = .white
        badge.backgroundColor = .systemRed
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            badge.heightAnchor.constraint(equalToConstant: 16),
            badge.topAnchor.constraint(equalTo: view.topAnchor),
            badge.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}
