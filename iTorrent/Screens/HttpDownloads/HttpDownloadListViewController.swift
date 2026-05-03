//
//  HttpDownloadListViewController.swift
//  iTorrent
//
//  Displays active and completed HTTP downloads with progress.
//

import Combine
import MvvmFoundation
import UIKit

class HttpDownloadListViewController: BaseViewController<HttpDownloadListViewModel> {

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(HttpDownloadCell.self, forCellReuseIdentifier: HttpDownloadCell.reuseId)
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No active downloads"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HTTP Downloads"

        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        // Clear completed button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear Done",
            style: .plain,
            target: self,
            action: #selector(clearCompleted)
        )

        viewModel.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.tableView.reloadData()
                self?.emptyLabel.isHidden = !items.isEmpty
            }
            .store(in: &cancellables)
    }

    @objc private func clearCompleted() {
        viewModel.clearCompleted()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension HttpDownloadListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HttpDownloadCell.reuseId, for: indexPath) as! HttpDownloadCell
        cell.configure(with: viewModel.items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 72 }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = viewModel.items[indexPath.row]

        let cancel = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            self?.viewModel.remove(at: IndexSet(integer: indexPath.row))
            done(true)
        }

        let toggleTitle = item.state == .downloading ? "Pause" : "Resume"
        let toggle = UIContextualAction(style: .normal, title: toggleTitle) { _, _, done in
            item.togglePauseResume()
            done(true)
        }
        toggle.backgroundColor = .systemOrange

        var actions: [UIContextualAction] = [cancel]
        if item.state == .downloading || item.state == .paused {
            actions.append(toggle)
        }

        return UISwipeActionsConfiguration(actions: actions)
    }
}

// MARK: - HttpDownloadCell

private class HttpDownloadCell: UITableViewCell {
    static let reuseId = "HttpDownloadCell"

    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var cancellables = Set<AnyCancellable>()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        selectionStyle = .none

        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingMiddle

        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [nameLabel, progressView, statusLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(with vm: HttpDownloadItemViewModel) {
        cancellables.removeAll()
        nameLabel.text = vm.fileName

        vm.$progress.receive(on: DispatchQueue.main).sink { [weak self] p in
            self?.progressView.progress = Float(p)
        }.store(in: &cancellables)

        Publishers.CombineLatest(vm.$state, vm.$bytesDownloaded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak vm] _, _ in
                guard let vm else { return }
                self?.statusLabel.text = "\(vm.stateText) — \(vm.progressText)"
            }
            .store(in: &cancellables)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancellables.removeAll()
    }
}
