//
//  TorrentListViewModel+HttpDownloads.swift
//  iTorrent
//
//  Injects HTTP downloads as a section at the top of the main torrent list.
//
//  INTEGRATION:
//  In TorrentListViewModel.swift, find the Publishers.combineLatest block
//  that ends with `.assign(to: &$sections)` and wrap it like this:
//
//      Publishers.combineLatest(
//          <existing publisher>,
//          HttpDownloadService.shared.$downloads
//      ) { torrentSections, httpDownloads in
//          Self.injectHttpSection(httpDownloads, into: torrentSections)
//      }
//      .assign(to: &$sections)
//
//  OR — simpler — add this after the existing .assign(to: &$sections):
//
//      HttpDownloadService.shared.$downloads
//          .receive(on: DispatchQueue.main)
//          .sink { [weak self] _ in
//              guard let self else { return }
//              // sections is already set, just re-inject
//          }
//          .store(in: &disposeBag) // if disposeBag supports this
//
//  The CLEANEST integration: replace the final .assign(to: &$sections) with:
//
//      .combineLatest(HttpDownloadService.shared.$downloads)
//      .map { sections, downloads in
//          TorrentListViewModel.injectHttpSection(downloads, into: sections)
//      }
//      .assign(to: &$sections)
//

import Combine
import MvvmFoundation

extension TorrentListViewModel {

    /// Prepends an "HTTP Downloads" section to the torrent sections if there are any downloads.
    static func injectHttpSection(_ downloads: [HttpDownloadItem], into sections: [MvvmCollectionSectionModel]) -> [MvvmCollectionSectionModel] {
        guard !downloads.isEmpty else { return sections }

        let httpItems = downloads.map { item -> HttpDownloadListItemViewModel in
            HttpDownloadListItemViewModel(item: item)
        }

        let httpSection = MvvmCollectionSectionModel(
            id: "httpDownloads",
            header: "HTTP Downloads",
            style: .platformPlain,
            showsSeparators: true,
            items: httpItems
        )

        return [httpSection] + sections
    }
}
