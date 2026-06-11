//
//  NSView+Extensions.swift
//  macOS-AppKit Template
//
//  Auto Layout convenience helpers for programmatic AppKit UIs.
//

import AppKit

extension NSView {

    /// Adds a subview and disables its autoresizing mask translation,
    /// preparing it for Auto Layout constraints.
    func addSubviewForAutoLayout(_ subview: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
    }

    /// Pins all four edges of the receiver to another view, with optional insets.
    /// - Parameters:
    ///   - other: The view to pin to (usually the superview).
    ///   - insets: Edge insets. Positive values inset the receiver.
    @discardableResult
    func pinEdges(to other: NSView, insets: NSEdgeInsets = NSEdgeInsetsZero) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    /// Pins the receiver's edges to its superview's layout margins/edges.
    @discardableResult
    func pinEdgesToSuperview(insets: NSEdgeInsets = NSEdgeInsetsZero) -> [NSLayoutConstraint] {
        guard let superview else {
            assertionFailure("pinEdgesToSuperview called before view was added to a superview.")
            return []
        }
        return pinEdges(to: superview, insets: insets)
    }

    /// Constrains the receiver to a fixed size.
    @discardableResult
    func constrainSize(width: CGFloat? = nil, height: CGFloat? = nil) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []
        if let width {
            constraints.append(widthAnchor.constraint(equalToConstant: width))
        }
        if let height {
            constraints.append(heightAnchor.constraint(equalToConstant: height))
        }
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    /// Centers the receiver within another view.
    @discardableResult
    func center(in other: NSView) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            centerXAnchor.constraint(equalTo: other.centerXAnchor),
            centerYAnchor.constraint(equalTo: other.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}
