import SwiftUI

/// A small coloured snooker ball with its point value, used to visualise the
/// balls in a break.
struct BallDot: View {
    let ball: SnookerBall
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(ball.color)
            .frame(width: size, height: size)
            .overlay {
                Text("\(ball.rawValue)")
                    .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                    .foregroundStyle(ball.textColor)
            }
            .overlay {
                Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5)
            }
    }
}

#Preview {
    FlowLayout(spacing: 6) {
        ForEach(Array([1, 7, 1, 7, 1, 6, 2, 3, 4, 5, 6, 7].enumerated()), id: \.offset) { _, value in
            BallDot(ball: SnookerBall(rawValue: value) ?? .red)
        }
    }
    .padding()
}
