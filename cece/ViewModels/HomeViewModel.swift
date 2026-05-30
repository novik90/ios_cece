import Foundation

/// Drives `HomeView`. Currently the home screen is purely navigational, so the
/// view model only exposes the static branding copy. It exists now so the
/// screen follows the same MVVM contract as the rest of the app.
@MainActor
final class HomeViewModel: ObservableObject {
    let title = "ce·ce"
    let subtitle = "one ball at a time."
}
