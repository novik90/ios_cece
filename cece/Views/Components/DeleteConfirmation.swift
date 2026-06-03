import SwiftUI

extension View {
    /// Standard swipe-to-delete action used across all lists: a red,
    /// icon-only (trash) button, no text. Apply it to a row inside a `ForEach`.
    func deleteSwipeAction(perform: @escaping () -> Void) -> some View {
        swipeActions(allowsFullSwipe: true) {
            Button(role: .destructive, action: perform) {
                Label("Delete", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .tint(Theme.Palette.destructive)
        }
    }

    /// Shared destructive-delete confirmation dialog.
    ///
    /// Drive it with an optional `item`: set it (e.g. from a row's `.onDelete`)
    /// to present the dialog; confirming calls `perform`. The destructive button
    /// is system red on every screen, keeping delete affordances consistent.
    func deleteConfirmation<Item>(
        _ title: LocalizedStringKey,
        item: Binding<Item?>,
        message: LocalizedStringKey,
        confirmLabel: LocalizedStringKey = "Delete",
        cancelLabel: LocalizedStringKey = "Cancel",
        perform: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(confirmLabel, role: .destructive) {
                if let value = item.wrappedValue { perform(value) }
                item.wrappedValue = nil
            }
            Button(cancelLabel, role: .cancel) { item.wrappedValue = nil }
        } message: {
            Text(message)
        }
    }
}
