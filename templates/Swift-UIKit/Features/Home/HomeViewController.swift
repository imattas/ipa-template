import UIKit
import Observation

/// Programmatic UIKit view controller for the Home feature.
///
/// Observes the `@Observable` view model using `withObservationTracking` and
/// re-renders whenever any accessed observable property changes.
@MainActor
final class HomeViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: HomeViewModel

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    private static let cellReuseID = "ItemCell"

    // MARK: - Init

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = .systemBackground

        setupTableView()
        setupActivityIndicator()
        observeViewModel()

        Task { await viewModel.load() }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseID)
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Observation

    /// Registers a one-shot observation. `withObservationTracking` fires the
    /// `onChange` closure once when any property read in `apply` changes, so we
    /// re-arm it after each render to keep observing.
    private func observeViewModel() {
        withObservationTracking {
            // Read every property we render so the tracker subscribes to them.
            _ = viewModel.items
            _ = viewModel.isLoading
            _ = viewModel.errorMessage
        } onChange: { [weak self] in
            // onChange is delivered off the main actor; hop back before UIKit work.
            Task { @MainActor [weak self] in
                self?.render()
                self?.observeViewModel()
            }
        }
        render()
    }

    private func render() {
        if viewModel.isLoading && viewModel.items.isEmpty {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        if !viewModel.isLoading {
            refreshControl.endRefreshing()
        }

        if let message = viewModel.errorMessage, viewModel.items.isEmpty {
            showError(message)
        }

        tableView.reloadData()
    }

    private func showError(_ message: String) {
        // TODO: Replace with a non-blocking inline error view if preferred.
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            Task { await self?.viewModel.load() }
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        Task { await viewModel.load() }
    }
}

// MARK: - UITableViewDataSource

extension HomeViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseID, for: indexPath)
        let item = viewModel.items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HomeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // TODO: Push a detail screen for viewModel.items[indexPath.row].
    }
}
