//
//  View+Extensions.swift
//  Swift-SwiftUI
//
//  Reusable SwiftUI view modifiers shared across features.
//

import SwiftUI

extension View {
    /// Applies a standard "card" appearance: padded, rounded background with a
    /// subtle shadow. Use for grouped content blocks.
    func cardStyle() -> some View {
        self
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    /// Conditionally applies a transform to the view.
    ///
    /// Prefer this over branching whole view hierarchies. Note: changing the
    /// condition can reset view identity, so avoid it for animated state.
    @ViewBuilder
    func `if`<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Redacts the view's content with a placeholder while `isLoading` is true.
    /// Pair with skeleton rows for a polished loading state.
    func redactedWhileLoading(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .disabled(isLoading)
    }
}
