//
//  SettingsViewController.swift
//  macOS-AppKit Template
//
//  Programmatic settings form backed by SettingsViewModel.
//

import AppKit

@MainActor
final class SettingsViewController: NSViewController {

    // MARK: - Dependencies

    private let viewModel: SettingsViewModel

    // MARK: - Controls

    private let usernameField = NSTextField()
    private let notificationsCheckbox = NSButton()
    private let refreshIntervalField = NSTextField()
    private let refreshStepper = NSStepper()
    private let resetButton = NSButton()

    // MARK: - Init

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used in this programmatic view controller.")
    }

    // MARK: - View Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 320))
        self.view = container
        buildForm(in: container)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        syncFromViewModel()
    }

    // MARK: - Form Construction

    private func buildForm(in container: NSView) {
        let usernameLabel = NSTextField(labelWithString: "Username:")
        usernameField.placeholderString = "Enter a username"
        usernameField.target = self
        usernameField.action = #selector(usernameChanged)

        notificationsCheckbox.setButtonType(.switch)
        notificationsCheckbox.title = "Enable notifications"
        notificationsCheckbox.target = self
        notificationsCheckbox.action = #selector(notificationsToggled)

        let refreshLabel = NSTextField(labelWithString: "Refresh interval (s):")
        refreshIntervalField.alignment = .right
        refreshIntervalField.target = self
        refreshIntervalField.action = #selector(refreshFieldChanged)

        refreshStepper.minValue = 5
        refreshStepper.maxValue = 600
        refreshStepper.increment = 5
        refreshStepper.valueWraps = false
        refreshStepper.target = self
        refreshStepper.action = #selector(refreshStepperChanged)

        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetTapped)

        // Lay the form out in a vertical stack of rows.
        let usernameRow = makeRow(label: usernameLabel, control: usernameField)
        let refreshRow = makeRow(label: refreshLabel, control: stepperRow())

        let stack = NSStackView(views: [usernameRow, notificationsCheckbox, refreshRow, resetButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        container.addSubviewForAutoLayout(stack)
        stack.pinEdgesToSuperview()
    }

    /// Wraps a label + control in a horizontal row.
    private func makeRow(label: NSView, control: NSView) -> NSStackView {
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    /// Combines the numeric field with its stepper.
    private func stepperRow() -> NSStackView {
        refreshIntervalField.constrainSize(width: 60)
        let row = NSStackView(views: [refreshIntervalField, refreshStepper])
        row.orientation = .horizontal
        row.spacing = 4
        row.alignment = .centerY
        return row
    }

    // MARK: - Sync

    /// Pushes current view-model values into the controls.
    private func syncFromViewModel() {
        usernameField.stringValue = viewModel.username
        notificationsCheckbox.state = viewModel.notificationsEnabled ? .on : .off
        refreshIntervalField.integerValue = viewModel.refreshInterval
        refreshStepper.integerValue = viewModel.refreshInterval
    }

    // MARK: - Actions

    @objc private func usernameChanged() {
        viewModel.username = usernameField.stringValue
    }

    @objc private func notificationsToggled() {
        viewModel.notificationsEnabled = (notificationsCheckbox.state == .on)
    }

    @objc private func refreshFieldChanged() {
        let value = refreshIntervalField.integerValue
        viewModel.refreshInterval = value
        refreshStepper.integerValue = value
    }

    @objc private func refreshStepperChanged() {
        let value = refreshStepper.integerValue
        viewModel.refreshInterval = value
        refreshIntervalField.integerValue = value
    }

    @objc private func resetTapped() {
        viewModel.resetToDefaults()
        syncFromViewModel()
    }
}
