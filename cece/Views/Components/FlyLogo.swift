import SwiftUI

/// Stylised "fly with a cue" mascot drawn with `Canvas` so no raster/SVG asset
/// is required. The fly body doubles as a snooker ball.
struct FlyLogo: View {
    var size: CGFloat = 120

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let cx = w * 0.5
            let cy = h * 0.56
            let bodyR = w * 0.22

            // MARK: Cue (drawn first so it sits behind the body)
            var cue = Path()
            cue.move(to: CGPoint(x: w * 0.18, y: h * 0.86))
            cue.addLine(to: CGPoint(x: w * 0.74, y: h * 0.30))
            context.stroke(
                cue,
                with: .color(Theme.Palette.border),
                style: StrokeStyle(lineWidth: w * 0.045, lineCap: .round)
            )
            // Cue tip
            context.fill(
                Path(ellipseIn: CGRect(
                    x: w * 0.74 - w * 0.03, y: h * 0.30 - w * 0.03,
                    width: w * 0.06, height: w * 0.06
                )),
                with: .color(Theme.Ball.blue)
            )

            // MARK: Wings
            let wingW = bodyR * 1.5
            let wingH = bodyR * 1.0
            for sign in [-1.0, 1.0] {
                var wing = Path()
                let originX = cx + CGFloat(sign) * bodyR * 0.4
                wing.addEllipse(in: CGRect(
                    x: originX - (sign < 0 ? wingW : 0),
                    y: cy - bodyR * 1.1,
                    width: wingW,
                    height: wingH
                ))
                context.fill(wing, with: .color(Theme.Palette.teal.opacity(0.25)))
                context.stroke(wing, with: .color(Theme.Palette.teal), lineWidth: w * 0.012)
            }

            // MARK: Body (the ball)
            let bodyRect = CGRect(x: cx - bodyR, y: cy - bodyR, width: bodyR * 2, height: bodyR * 2)
            context.fill(Path(ellipseIn: bodyRect), with: .color(Theme.Ball.black))
            // Highlight
            context.fill(
                Path(ellipseIn: CGRect(
                    x: cx - bodyR * 0.55, y: cy - bodyR * 0.55,
                    width: bodyR * 0.5, height: bodyR * 0.5
                )),
                with: .color(.white.opacity(0.25))
            )

            // MARK: Head
            let headR = bodyR * 0.55
            let headCy = cy - bodyR * 1.05
            context.fill(
                Path(ellipseIn: CGRect(
                    x: cx - headR, y: headCy - headR,
                    width: headR * 2, height: headR * 2
                )),
                with: .color(Theme.Ball.black)
            )
            // Eyes
            for sign in [-1.0, 1.0] {
                let eyeR = headR * 0.45
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: cx + CGFloat(sign) * headR * 0.5 - eyeR,
                        y: headCy - eyeR * 0.8,
                        width: eyeR * 2, height: eyeR * 2
                    )),
                    with: .color(Theme.Ball.red)
                )
            }

            // MARK: Antennae
            for sign in [-1.0, 1.0] {
                var ant = Path()
                ant.move(to: CGPoint(x: cx + CGFloat(sign) * headR * 0.3, y: headCy - headR * 0.6))
                ant.addQuadCurve(
                    to: CGPoint(x: cx + CGFloat(sign) * headR * 1.3, y: headCy - headR * 1.6),
                    control: CGPoint(x: cx + CGFloat(sign) * headR * 1.2, y: headCy - headR * 0.6)
                )
                context.stroke(ant, with: .color(Theme.Ball.black), lineWidth: w * 0.012)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("ce·ce logo")
    }
}

#Preview {
    FlyLogo(size: 160)
        .padding()
        .background(Theme.Palette.background)
}
