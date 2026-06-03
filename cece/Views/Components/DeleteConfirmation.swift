import SwiftUI

extension View {
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
