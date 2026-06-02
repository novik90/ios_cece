import SwiftUI

/// A single match node rendered as a card in the bracket. Shows both slots with
/// names and (once played) frame scores, a status badge, and forwards taps when
/// the match is ready to start or resume.
struct BracketMatchCard: View {
    let node: TournamentMatch
    let namesById: [UUID: String]
    let onTap: () -> Void

    enum Status {
        case waiting, ready, inProgress, completed

        var label: String {
            switch self {
            case .waiting: return "Ожидание"
            case .ready: return "Готов"
            case .inProgress: return "Идёт"
            case .completed: return "Завершён"
            }
        }

        var color: Color {
            switch self {
            case .waiting: return Theme.Palette.textSecondary
            case .ready: return Theme.Palette.teal
            case .inProgress: return Theme.Palette.blue
            case .completed: return Theme.Palette.textPrimary
            }
        }
    }

    private var status: Status {
        if node.match?.completedAt != nil { return .completed }
        if node.match != nil { return .inProgress }
        if node.isReady { return .ready }
        return .waiting
    }

    private var isTappable: Bool { status == .ready || status == .inProgress }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            slotRow(node.slot1PlayerId)
            Divider()
            slotRow(node.slot2PlayerId)
            statusBadge
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTappable ? status.color : Theme.Palette.border,
                        lineWidth: isTappable ? 1.5 : 1)
        )
        .frame(width: 168)
        .contentShape(Rectangle())
        .onTapGesture { if isTappable { onTap() } }
    }

    private func slotRow(_ id: UUID?) -> some View {
        let isWinner = id != nil && node.match?.winnerId == id
        return HStack {
            Text(name(id))
                .font(.subheadline.weight(isWinner ? .bold : .regular))
                .foregroundStyle(id == nil ? Theme.Palette.textSecondary : Theme.Palette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if node.match != nil {
                Text("\(frames(id))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isWinner ? Theme.Palette.teal : Theme.Palette.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        HStack {
            Text(status.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(status.color)
            Spacer()
            if isTappable {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.08))
    }

    private func name(_ id: UUID?) -> String {
        guard let id else { return "—" }
        return namesById[id] ?? "—"
    }

    private func frames(_ id: UUID?) -> Int {
        guard let id, let match = node.match else { return 0 }
        return match.frames.filter { $0.winnerId == id }.count
    }
}
