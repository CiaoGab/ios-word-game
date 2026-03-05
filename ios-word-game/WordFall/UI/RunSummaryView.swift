import SwiftUI

struct RunSummaryView: View {
    let snapshot: RunSummarySnapshot
    let onBackToMenu: () -> Void
    let onPlayAgain: () -> Void

    @State private var shareErrorMessage: String?

    var body: some View {
        ZStack {
            ParchmentTheme.Roguelike.Palette.backdrop
                .ignoresSafeArea()

            summaryCard
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
        }
        .alert("Share Run", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 20) {
            headerSection
            topStats
            groupedStats
            buttonsSection
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(
                cornerRadius: ParchmentTheme.Roguelike.Radius.modalCard,
                style: .continuous
            )
            .fill(ParchmentTheme.Roguelike.Palette.cardBackground)
        )
        .shadow(
            color: ParchmentTheme.Roguelike.Shadow.modal.color,
            radius: ParchmentTheme.Roguelike.Shadow.modal.radius,
            x: ParchmentTheme.Roguelike.Shadow.modal.x,
            y: ParchmentTheme.Roguelike.Shadow.modal.y
        )
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RUN SUMMARY")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(ParchmentTheme.Roguelike.Palette.goldAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(snapshot.wonRun ? "Act 3 Complete" : "Run Ended")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onBackToMenu) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ParchmentTheme.Roguelike.Palette.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(ParchmentTheme.Roguelike.Palette.tileBackground)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close summary")
        }
    }

    private var topStats: some View {
        HStack(spacing: 12) {
            statTile(
                label: "TOTAL SCORE",
                value: "\(snapshot.totalScore)",
                valueColor: ParchmentTheme.Roguelike.Palette.goldAccent
            )
            statTile(
                label: "BOARDS CLEARED",
                value: snapshot.boardsProgressText,
                valueColor: ParchmentTheme.Roguelike.Palette.textPrimary
            )
        }
    }

    private func statTile(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)

            Text(value)
                .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ParchmentTheme.Roguelike.Radius.tile, style: .continuous)
                .fill(ParchmentTheme.Roguelike.Palette.tileBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Roguelike.Radius.tile, style: .continuous)
                        .stroke(ParchmentTheme.Roguelike.Palette.tileStroke, lineWidth: 1)
                )
        )
        .shadow(
            color: ParchmentTheme.Roguelike.Shadow.tile.color,
            radius: ParchmentTheme.Roguelike.Shadow.tile.radius,
            x: ParchmentTheme.Roguelike.Shadow.tile.x,
            y: ParchmentTheme.Roguelike.Shadow.tile.y
        )
    }

    private var groupedStats: some View {
        VStack(spacing: 0) {
            groupedRow(
                icon: "lock.open.fill",
                title: "Locks Broken",
                value: "\(snapshot.locksBroken)",
                valueColor: ParchmentTheme.Roguelike.Palette.textPrimary
            )
            Divider().overlay(ParchmentTheme.Roguelike.Palette.tileStroke)
            groupedRow(
                icon: "text.badge.checkmark",
                title: "Words Built",
                value: "\(snapshot.wordsBuilt)",
                valueColor: ParchmentTheme.Roguelike.Palette.textPrimary
            )
            Divider().overlay(ParchmentTheme.Roguelike.Palette.tileStroke)
            groupedRow(
                icon: "star.fill",
                title: "Best Word",
                value: bestWordText,
                valueColor: ParchmentTheme.Roguelike.Palette.goldAccent
            )
        }
        .background(
            RoundedRectangle(cornerRadius: ParchmentTheme.Roguelike.Radius.rowCard, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Roguelike.Radius.rowCard, style: .continuous)
                        .stroke(ParchmentTheme.Roguelike.Palette.tileStroke, lineWidth: 1)
                )
        )
    }

    private func groupedRow(icon: String, title: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var buttonsSection: some View {
        VStack(spacing: 10) {
            actionButton(
                title: "Back to Menu",
                background: ParchmentTheme.Roguelike.Palette.goldAccent,
                foreground: .white,
                action: onBackToMenu
            )
            actionButton(
                title: "Play Again",
                background: ParchmentTheme.Roguelike.Palette.tileBackground,
                foreground: ParchmentTheme.Roguelike.Palette.textPrimary,
                action: onPlayAgain
            )
            actionButton(
                title: "Share Run",
                background: ParchmentTheme.Roguelike.Palette.darkButton,
                foreground: ParchmentTheme.Roguelike.Palette.darkButtonText,
                action: shareRun
            )
        }
    }

    private func actionButton(
        title: String,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Roguelike.Radius.button, style: .continuous)
                        .fill(background)
                )
        }
        .buttonStyle(.plain)
    }

    private var bestWordText: String {
        guard !snapshot.bestWord.isEmpty else { return "—" }
        return "\(snapshot.bestWord.uppercased()) (\(snapshot.bestWordScore))"
    }

    private func shareRun() {
        guard let image = ShareCardImageRenderer.makeImage(snapshot: snapshot) else {
            shareErrorMessage = "Could not generate share card image."
            return
        }
        let presented = ShareSheetPresenter.present(items: [image])
        if !presented {
            shareErrorMessage = "Could not present share sheet."
        }
    }
}

#Preview {
    RunSummaryView(
        snapshot: RunSummarySnapshot(
            wonRun: false,
            totalScore: 2730,
            boardsCleared: 7,
            totalBoards: 15,
            boardReached: 8,
            locksBroken: 64,
            wordsBuilt: 121,
            bestWord: "REARRANGE",
            bestWordScore: 450
        ),
        onBackToMenu: {},
        onPlayAgain: {}
    )
}
