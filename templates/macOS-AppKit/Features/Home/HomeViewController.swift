//
//  HomeViewController.swift
//  macOS-AppKit Template
//
//  Programmatic AppKit view controller hosting a view-based NSTableView.
//

import AppKit
import Observation

@MainActor
final class HomeViewController: NSViewController {

    // MARK: - Dependencies

    private let viewModel: HomeViewModel

    // MARK: - Subviews

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let refreshButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()

    /// Column identifier used by the single-column table.
    private let itemColumnID = NSUserInterfaceItemIdentifier("ItemColumn")
    private let cellID = NSUserInterfaceItemIdentifier("ItemCell")

    // MARK: - Init

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used in this programmatic view controller.")
    }

    // MARK: - View Lifecycle

    /// Build the view hierarchy programmatically (no nib).
    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        self.view = container

        configureToolbarRow(in: container)
        configureTable(in: container)
        configureStatusLabel(in: container)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        observeViewModel()
        Task { await viewModel.loadItems() }
    }

    // MARK: - UI Construction

    private func configureToolbarRow(in container: NSView) {
        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(didTapRefresh)
        container.addSubviewForAutoLayout(refreshButton)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        container.addSubviewForAutoLayout(progressIndicator)

        NSLayoutConstraint.activate([
            refreshButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            refreshButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            progressIndicator.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8)
        ])
    }

    private func configureTable(in container: NSView) {
        let column = NSTableColumn(identifier: itemColumnID)
        column.title = "Items"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.headerView = NSTableHeaderView()
        tableView.usesAutomaticRowHeights = true
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        container.addSubviewForAutoLayout(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
        ])
    }

    private func configureStatusLabel(in container: NSView) {
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        container.addSubviewForAutoLayout(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Actions

    @objc private func didTapRefresh() {
        Task { await viewModel.loadItems() }
    }

    // MARK: - Observation

    /// Re-renders whenever any observed property of the view model changes.
    ///
    /// `withObservationTracking` fires its `onChange` once; we re-register after
    /// each render to keep observing. This is the standard pattern for using
    /// `@Observable` outside of SwiftUI.
    private func observeViewModel() {
        withObservationTracking {
            // Touch every property we render so they are tracked.
            _ = viewModel.items
            _ = viewModel.isLoading
            _ = viewModel.errorMessage
        } onChange: { [weak self] in
            // onChange runs off the main actor's current context; hop back on.
            Task { @MainActor in
                self?.render()
                self?.observeViewModel()
            }
        }
        // Initial render.
        render()
    }

    /// Pushes current view-model state into the UI.
    private func render() {
        if viewModel.isLoading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        refreshButton.isEnabled = !viewModel.isLoading

        if let errorMessage = viewModel.errorMessage {
            statusLabel.stringValue = "Error: \(errorMessage)"
            statusLabel.textColor = .systemRed
        } else {
            statusLabel.stringValue = "\(viewModel.itemCount) item(s)"
            statusLabel.textColor = .secondaryLabelColor
        }

        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

extension HomeViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.itemCount
    }
}

// MARK: - NSTableViewDelegate

extension HomeViewController: NSTableViewDelegate {

    /// Builds (or recycles) a view-based cell for the given row.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let item = viewModel.item(at: row) else { return nil }

        // Recycle an existing cell if possible.
        let cell: NSTableCellView
        if let recycled = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = recycled
        } else {
            cell = makeCell()
        }

        cell.textField?.stringValue = item.title
        // Subtitle is shown via the cell's tooltip for this minimal template.
        // TODO: Promote to a two-line cell if your design needs a subtitle row.
        cell.toolTip = item.subtitle

        return cell
    }

    /// Creates a reusable single-label cell view.
    private func makeCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = cellID

        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubviewForAutoLayout(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
        ])

        return cell
    }
}
