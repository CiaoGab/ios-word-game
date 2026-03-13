import SwiftUI
import UIKit

struct ShareCardView: View {
    static let exportSize = CGSize(width: 1200, height: 630)

    let snapshot: RunSummarySnapshot

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF8FAFC),
                    Color(hex: 0xE5E7EB)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            decorativePattern

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(ParchmentTheme.Roguelike.Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(ParchmentTheme.Roguelike.Palette.tileStroke, lineWidth: 3)
                )
                .padding(34)
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)

            HStack(alignment: .top, spacing: 32) {
                leftColumn
                rightColumn
            }
            .padding(.horizontal, 74)
            .padding(.vertical, 58)
        }
        .frame(width: ShareCardView.exportSize.width, height: ShareCardView.exportSize.height)
    }

    private var decorativePattern: some View {
        ZStack {
            Circle()
                .fill(ParchmentTheme.Roguelike.Palette.goldAccent.opacity(0.08))
                .frame(width: 360, height: 360)
                .offset(x: 420, y: -250)

            Circle()
                .fill(ParchmentTheme.Roguelike.Palette.darkButton.opacity(0.05))
                .frame(width: 320, height: 320)
                .offset(x: -460, y: 260)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("WordFall")
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("RUN SUMMARY")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .tracking(2.6)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.goldAccent)

            Text(snapshot.wonRun ? "Run Complete" : "Run Ended")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)

            progressBlock

            Spacer(minLength: 0)

            Text("wordfall")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary.opacity(0.74))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("TOTAL SCORE")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)

            Text("\(snapshot.totalScore)")
                .font(.system(size: 92, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.goldAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            VStack(spacing: 0) {
                detailRow(title: "Rounds Cleared", value: snapshot.roundsProgressText, emphasized: false)
                Divider().overlay(ParchmentTheme.Roguelike.Palette.tileStroke)
                detailRow(title: "Best Word", value: bestWordText, emphasized: true)
                Divider().overlay(ParchmentTheme.Roguelike.Palette.tileStroke)
                detailRow(title: "Locks Broken", value: "\(snapshot.locksBroken)", emphasized: false)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ParchmentTheme.Roguelike.Palette.tileStroke, lineWidth: 2)
                    )
            )
        }
        .frame(width: 490, alignment: .leading)
    }

    private func detailRow(title: String, value: String, emphasized: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(emphasized
                    ? ParchmentTheme.Roguelike.Palette.goldAccent
                    : ParchmentTheme.Roguelike.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROGRESS")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)

            GeometryReader { proxy in
                let width = max(0, proxy.size.width)
                let fillWidth = width * progressFraction

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(ParchmentTheme.Roguelike.Palette.tileStroke.opacity(0.40))
                    Capsule(style: .continuous)
                        .fill(ParchmentTheme.Roguelike.Palette.goldAccent)
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 14)

            Text("R\(snapshot.roundReached) of \(snapshot.totalRounds)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textPrimary)
        }
        .frame(width: 420, alignment: .leading)
    }

    private var bestWordText: String {
        guard !snapshot.bestWord.isEmpty else { return "—" }
        return "\(snapshot.bestWord.uppercased()) (\(snapshot.bestWordScore))"
    }

    private var progressFraction: CGFloat {
        guard snapshot.totalRounds > 0 else { return 0 }
        let progressRound = max(snapshot.roundReached, snapshot.roundsCleared)
        let raw = Double(progressRound) / Double(snapshot.totalRounds)
        return CGFloat(min(max(raw, 0), 1))
    }
}

@MainActor
enum ShareCardImageRenderer {
    static func makeImage(snapshot: RunSummarySnapshot) -> UIImage? {
        let size = ShareCardView.exportSize
        let scale = UIApplication.shared.activeKeyWindow?.screen.scale ?? 3.0
        let content = ShareCardView(snapshot: snapshot)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light)

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(size)
            renderer.scale = scale
            if let image = renderer.uiImage {
                return image
            }
        }

        return fallbackImage(content: AnyView(content), size: size, scale: scale)
    }

    private static func fallbackImage(content: AnyView, size: CGSize, scale: CGFloat) -> UIImage? {
        let controller = UIHostingController(rootView: content)
        controller.overrideUserInterfaceStyle = .light
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any]) -> Bool {
        guard let topController = UIApplication.shared.topMostViewController() else {
            return false
        }

        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        topController.present(activityVC, animated: true)
        return true
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let rootController = base ?? activeKeyWindow?.rootViewController
        guard let rootController else { return nil }

        if let nav = rootController as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = rootController as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = rootController.presentedViewController {
            return topMostViewController(base: presented)
        }

        return rootController
    }

    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)
    }
}

#Preview {
    ShareCardView(
        snapshot: RunSummarySnapshot(
            wonRun: true,
            totalScore: 6230,
            xpEarned: 982,
            totalXPAfterRun: 2440,
            roundsCleared: 50,
            totalRounds: 50,
            roundReached: 50,
            locksBroken: 132,
            wordsBuilt: 247,
            bestWord: "REARRANGE",
            bestWordScore: 450,
            challengeRoundsCleared: 5,
            rareLetterWordUsed: true,
            newUnlocks: [.equipSlot4]
        )
    )
}
