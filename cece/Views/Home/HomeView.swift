import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    let dependencies: Dependencies

    /// Routes reachable from the home screen.
    private enum Route: Hashable {
        case newMatch, newPlayer, reviewMatches, reviewPlayers
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    branding
                    Spacer(minLength: 32)
                    actions
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .newMatch:
                    NewMatchView(dependencies: dependencies)
                case .newPlayer:
                    NewPlayerView(dependencies: dependencies)
                case .reviewMatches:
                    ReviewMatchesView(dependencies: dependencies)
                case .reviewPlayers:
                    ReviewPlayersView(dependencies: dependencies)
                }
            }
        }
    }

    // MARK: - Branding

    private var branding: some View {
        VStack(spacing: 8) {
            FlyLogo(size: 140)
            Text(viewModel.title)
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(viewModel.subtitle)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 16) {
            NavigationLink(value: Route.newMatch) {
                HomePrimaryRow(
                    iconSystemName: "plus",
                    iconBackground: Theme.Palette.teal,
                    title: "New match"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: Route.newPlayer) {
                HomePrimaryRow(
                    iconSystemName: "person.badge.plus",
                    iconBackground: Theme.Palette.blue,
                    title: "New player"
                )
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, 4)

            NavigationLink(value: Route.reviewMatches) {
                HomeSecondaryRow(iconSystemName: "rectangle.split.2x1", title: "Review matches")
            }
            .buttonStyle(.plain)

            NavigationLink(value: Route.reviewPlayers) {
                HomeSecondaryRow(iconSystemName: "person", title: "Review players")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Rows

/// Bordered primary action row: coloured icon tile, title, chevron.
private struct HomePrimaryRow: View {
    let iconSystemName: String
    let iconBackground: Color
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(iconBackground)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Palette.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Palette.border, lineWidth: 1.5)
        )
        // Make the entire row (incl. the Spacer gap) tappable, not just the
        // text/icon/chevron.
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Borderless secondary action row in the secondary text colour.
private struct HomeSecondaryRow: View {
    let iconSystemName: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconSystemName)
                .font(.system(size: 17, weight: .regular))
                .frame(width: 38)
            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // Make the entire row tappable, including the empty Spacer area.
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeView(dependencies: PreviewData.dependencies)
}
