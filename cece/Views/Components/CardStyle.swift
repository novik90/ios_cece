import SwiftUI

extension View {
    /// Card surface: the standard rounded surface fill with an optional border.
    /// Content is clipped to the rounded shape.
    func cardStyle(
        cornerRadius: CGFloat = Theme.Radius.medium,
        border: Color? = nil,
        lineWidth: CGFloat = 1
    ) -> some View {
        self
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(border, lineWidth: lineWidth)
                }
            }
    }
}
