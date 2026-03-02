import SwiftUI
import SpriteKit

struct GameScreen: View {
    @StateObject private var session = GameSessionController()
    @State private var showDebugHUD: Bool = false

    var body: some View {
        ZStack {
            ParchmentBackdrop()
                .ignoresSafeArea()

            VStack(spacing: ParchmentTheme.Spacing.lg) {
                hud

                boardSection

                bottomBar

                debugOverlay
            }
            .padding(.horizontal, ParchmentTheme.Spacing.lg)
            .padding(.top, ParchmentTheme.Spacing.lg)
            .padding(.bottom, 22)
        }
    }

    private var hud: some View {
        VStack(spacing: ParchmentTheme.Spacing.sm) {
            HStack {
                hudPill(title: "Score", value: "\(session.score)")
                Spacer()
                hudPill(title: "Moves", value: "\(session.moves)")
            }

            HStack(spacing: ParchmentTheme.Spacing.sm) {
                Text(session.objectivesText)
                    .font(.parchmentRounded(size: 17, weight: .heavy))
                    .foregroundStyle(ParchmentTheme.Palette.objectiveGreenText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ParchmentTheme.Palette.white)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(ParchmentTheme.Palette.objectiveGreen, lineWidth: 4)
                            )
                    )
                    .shadow(color: ParchmentTheme.Palette.ink.opacity(0.1), radius: 0, x: 0, y: 2)
                    .rotationEffect(.degrees(-1))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var boardSection: some View {
        GeometryReader { proxy in
            SpriteView(scene: session.scene)
                .onAppear {
                    session.updateSceneSize(proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    session.updateSceneSize(newSize)
                }
        }
        .shadow(
            color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.board.opacity),
            radius: ParchmentTheme.Shadow.board.radius,
            x: ParchmentTheme.Shadow.board.x,
            y: ParchmentTheme.Shadow.board.y
        )
        .aspectRatio(1, contentMode: .fit)
    }

    private var bottomBar: some View {
        HStack(spacing: ParchmentTheme.Spacing.sm) {
            toyLabelButton(
                "Powerups",
                fill: ParchmentTheme.Palette.footerBlue,
                stroke: ParchmentTheme.Palette.footerBlueStroke
            )
            toyLabelButton(
                "Bottle",
                fill: ParchmentTheme.Palette.footerYellow,
                stroke: ParchmentTheme.Palette.footerYellowStroke
            )
            toyLabelButton(
                session.isAnimating ? "Animating..." : "Ready",
                fill: ParchmentTheme.Palette.footerRed,
                stroke: ParchmentTheme.Palette.footerRedStroke
            )
            Button(action: { showDebugHUD.toggle() }) {
                toyLabel(
                    showDebugHUD ? "Debug ON" : "Debug OFF",
                    fill: ParchmentTheme.Palette.footerPurple,
                    stroke: ParchmentTheme.Palette.footerPurpleStroke
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var debugOverlay: some View {
        if showDebugHUD {
            VStack(spacing: 4) {
                HStack {
                    Text("lastSubmittedWord: \(session.lastSubmittedWord.isEmpty ? "—" : session.lastSubmittedWord)")
                    Spacer()
                }

                HStack {
                    Text("status: \(session.status)")
                    Spacer()
                }

                HStack {
                    Text("locksBrokenThisMove: \(session.locksBrokenThisMove)")
                    Spacer()
                }

                HStack {
                    Text("locksBrokenTotal: \(session.locksBrokenTotal)")
                    Spacer()
                }

                HStack {
                    Text("currentLockedCount: \(session.currentLockedCount)")
                    Spacer()
                }

                HStack {
                    Text("usedTileIdsCount: \(session.usedTileIdsCount)")
                    Spacer()
                }

                HStack {
                    Text("activePathLength: \(session.activePathLength)")
                    Spacer()
                }

                HStack {
                    Text("hintWord: \(session.hintWord ?? "—")")
                    Spacer()
                }

                HStack {
                    Text("hintIndices: \(session.hintPath?.map { "\($0)" }.joined(separator: ",") ?? "—")")
                    Spacer()
                }

                HStack {
                    Text("hintIsValid: \(session.hintIsValid ? "true" : "false")")
                    Spacer()
                }
            }
            .font(.caption.monospaced())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ParchmentTheme.Palette.ink.opacity(0.25), lineWidth: 1)
                    )
            )
            .foregroundStyle(ParchmentTheme.Palette.ink)
        }
    }

    private func hudPill(title: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.parchmentRounded(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(ParchmentTheme.Palette.slate)
            Text(value)
                .font(.parchmentRounded(size: 22, weight: .heavy).monospacedDigit())
                .foregroundStyle(ParchmentTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(ParchmentTheme.Palette.white)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink, lineWidth: ParchmentTheme.Stroke.hud)
                )
        )
        .shadow(
            color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.hud.opacity),
            radius: ParchmentTheme.Shadow.hud.radius,
            x: ParchmentTheme.Shadow.hud.x,
            y: ParchmentTheme.Shadow.hud.y
        )
        .rotationEffect(.degrees(title == "Score" ? -1.4 : 1.1))
    }

    private func toyLabelButton(_ text: String, fill: Color, stroke: Color) -> some View {
        toyLabel(text, fill: fill, stroke: stroke)
    }

    private func toyLabel(_ text: String, fill: Color, stroke: Color) -> some View {
        Text(text)
            .font(.parchmentRounded(size: 14, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 21)
            .background(
                RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                            .stroke(stroke, lineWidth: ParchmentTheme.Stroke.button)
                    )
            )
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.button.opacity),
                radius: ParchmentTheme.Shadow.button.radius,
                x: ParchmentTheme.Shadow.button.x,
                y: ParchmentTheme.Shadow.button.y
            )
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(0.16),
                radius: 5,
                x: 0,
                y: 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button - 16, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4.5)
            )
    }
}

private struct ParchmentBackdrop: View {
    var body: some View {
        ZStack {
            ParchmentTheme.Palette.paperBase

            Canvas { context, size in
                for row in 0...12 {
                    for col in 0...7 {
                        let x = (CGFloat(col) + 0.4) * (size.width / 7.5)
                        let y = (CGFloat(row) + 0.35) * (size.height / 12.5)
                        let dot = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                        context.fill(Ellipse().path(in: dot), with: .color(ParchmentTheme.Palette.paperDust.opacity(0.24)))

                        let smudge = CGRect(x: x - 26, y: y - 9, width: 52, height: 18)
                        context.fill(
                            Ellipse().path(in: smudge),
                            with: .color(ParchmentTheme.Palette.paperDust.opacity(0.09))
                        )
                    }
                }

                var doodle = Path()
                doodle.move(to: CGPoint(x: 24, y: 36))
                doodle.addCurve(
                    to: CGPoint(x: 176, y: 132),
                    control1: CGPoint(x: 92, y: 8),
                    control2: CGPoint(x: 136, y: 178)
                )
                context.stroke(
                    doodle,
                    with: .color(ParchmentTheme.Palette.paperDoodle.opacity(0.3)),
                    lineWidth: 2.5
                )

                var doodle2 = Path()
                doodle2.addEllipse(in: CGRect(x: size.width - 84, y: 22, width: 30, height: 30))
                context.stroke(
                    doodle2,
                    with: .color(ParchmentTheme.Palette.paperDoodle.opacity(0.22)),
                    lineWidth: 2.5
                )
            }
        }
    }
}

#Preview {
    GameScreen()
}
