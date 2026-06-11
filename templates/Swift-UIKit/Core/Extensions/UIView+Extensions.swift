import UIKit

extension UIView {

    /// Adds `subview` and pins all four edges to the receiver, optionally insetting.
    /// Disables `translatesAutoresizingMaskIntoConstraints` on the subview.
    func addPinned(_ subview: UIView, insets: UIEdgeInsets = .zero) {
        addSubview(subview)
        subview.pinEdges(to: self, insets: insets)
    }

    /// Pins the receiver's edges to another view.
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom),
        ])
    }

    /// Pins the receiver's edges to another view's safe area layout guide.
    func pinEdgesToSafeArea(of other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        let guide = other.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: guide.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -insets.bottom),
        ])
    }

    /// Centers the receiver within another view.
    func center(in other: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: other.centerXAnchor),
            centerYAnchor.constraint(equalTo: other.centerYAnchor),
        ])
    }

    /// Constrains the receiver to a fixed size.
    func constrainSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
        if let width { widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height { heightAnchor.constraint(equalToConstant: height).isActive = true }
    }
}
