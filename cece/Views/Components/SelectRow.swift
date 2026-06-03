import SwiftUI

/// A tappable form row: a title on the left, the current value (or a
/// placeholder) and a chevron on the right. Used by the match and tournament
/// creation flows to pick players/seeds.
struct SelectRow: View {
    let title: LocalizedStringKey
    let value: String?
    var placeholder: LocalizedStringKey = "Select"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if let value {
                    Text(value)  // a player's name — shown verbatim
                        .foregroundStyle(Theme.Palette.textSecondary)
                } else {
                    Text(placeholder)
                        .foregroundStyle(Color.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
