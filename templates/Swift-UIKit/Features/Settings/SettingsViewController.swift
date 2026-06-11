import UIKit
import Observation

/// Programmatic UIKit settings screen with toggles backed by the view model.
@MainActor
final class SettingsViewController: UIViewController {

    private let viewModel: SettingsViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Row: Int, CaseIterable {
        case notifications
        case darkMode
        case version
    }

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Toggle handling

    @objc private func notificationsToggled(_ sender: UISwitch) {
        viewModel.isNotificationsEnabled = sender.isOn
    }

    @objc private func darkModeToggled(_ sender: UISwitch) {
        viewModel.isDarkModePreferred = sender.isOn
        // TODO: Apply the user's appearance preference to the active window scene.
    }

    private func makeSwitch(isOn: Bool, action: Selector) -> UISwitch {
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)
        return toggle
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        cell.selectionStyle = .none
        cell.accessoryView = nil

        switch Row(rawValue: indexPath.row) {
        case .notifications:
            config.text = "Notifications"
            cell.accessoryView = makeSwitch(
                isOn: viewModel.isNotificationsEnabled,
                action: #selector(notificationsToggled(_:))
            )
        case .darkMode:
            config.text = "Prefer Dark Mode"
            cell.accessoryView = makeSwitch(
                isOn: viewModel.isDarkModePreferred,
                action: #selector(darkModeToggled(_:))
            )
        case .version:
            config.text = "Version"
            config.secondaryText = viewModel.appVersion
        case .none:
            break
        }

        cell.contentConfiguration = config
        return cell
    }
}
