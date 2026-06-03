import SwiftUI

/// A tappable form row: a title on the left, the current value (or a
/// placeholder) and a chevron on the right. Used by the match and tournament
/// creation flows to pick players/seeds.
struct SelectRow: View {
    let title: String
    let value: String?
    var placeholder: String = "Select"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(value ?? placeholder)
                    .foregroundStyle(value == nil ? Color.secondary : Theme.Palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
