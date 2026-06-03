import SwiftUI

/// A standard list row: a title with an optional caption line and an optional
/// trailing accessory on the caption line. Used across the player and tournament
/// lists.
struct ListRow<Trailing: View>: View {
    /// A name shown verbatim (player/tournament), not localized.
    let title: String
    var titleFont: Font = .body
    /// Localizable caption (e.g. "%lld players").
    var caption: LocalizedStringKey? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(Theme.Palette.textPrimary)

            HStack {
                if let caption { Text(caption) }
                Spacer(minLength: 0)
                trailing()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

extension ListRow where Trailing == EmptyView {
    init(title: String, titleFont: Font = .body, caption: LocalizedStringKey? = nil) {
        self.init(title: title, titleFont: titleFont, caption: caption) { EmptyView() }
    }
}
