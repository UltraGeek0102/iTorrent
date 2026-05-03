//
//  HttpDownloadListItemView.swift
//  iTorrent
//

import MvvmFoundation
import SwiftUI
import UIKit

struct HttpDownloadListItemView: MvvmSwiftUICellProtocol {
    typealias ViewModel = HttpDownloadListItemViewModel

    @ObservedObject var viewModel: HttpDownloadListItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.title)
                .foregroundStyle(.primary)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.progressText)
                Text(viewModel.statusText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.secondary)
            .font(.footnote)
            ProgressView(value: viewModel.progress)
                .tint(viewModel.item.state == .completed ? .green : .orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.cancelDownload()
            } label: {
                Image(systemName: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            if viewModel.item.state == .downloading || viewModel.item.state == .paused {
                Button {
                    viewModel.togglePauseResume()
                } label: {
                    Image(systemName: viewModel.item.state == .downloading ? "pause.fill" : "play.fill")
                }
                .tint(.orange)
            }
        }
    }

    static let registration: UICollectionView.CellRegistration<UICollectionViewListCell, ViewModel> = .init { cell, _, itemIdentifier in
        cell.contentConfiguration = UIHostingConfiguration {
            HttpDownloadListItemView(viewModel: itemIdentifier)
        }

        var config: UIBackgroundConfiguration
        if #available(iOS 18.0, *) {
            config = .listCell()
        } else {
            config = .listPlainCell()
        }

        config.backgroundColorTransformer = .init { color in
            guard !cell.isHighlighted, !cell.isSelected
            else { return color }
            return .clear
        }
        cell.backgroundConfiguration = config
        cell.accessories = []
    }
}
