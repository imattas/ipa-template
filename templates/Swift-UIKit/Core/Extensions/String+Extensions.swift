import Foundation

extension String {

    /// Whitespace- and newline-trimmed copy.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns `true` if the string looks like a valid email address.
    var isValidEmail: Bool {
        // Pragmatic RFC 5322-ish pattern; good enough for client-side validation.
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }

    /// Looks up the receiver as a key in `Localizable.strings`.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Localized string with format arguments.
    func localized(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }

    /// `nil` if the string is empty after trimming, otherwise the trimmed value.
    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
