import UIKit
import SwiftUI

/// Simple accessory that guarantees a non-zero width and safe constraints.
final class STSKeyboardAccessoryView: UIView {
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Provide non-zero starting frame to avoid constraint conflicts on first layout.
        self.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = .init(top: 0, left: 20, bottom: 0, right: 20)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    func setItems(_ views: [UIView]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        views.forEach { stack.addArrangedSubview($0) }
    }
}

/// SwiftUI wrapper for easy use.
struct STSKeyboardAccessory: UIViewRepresentable {
    let items: [UIView]

    func makeUIView(context: Context) -> STSKeyboardAccessoryView {
        let v = STSKeyboardAccessoryView()
        v.setItems(items)
        return v
    }

    func updateUIView(_ uiView: STSKeyboardAccessoryView, context: Context) {
        uiView.setItems(items)
    }
}