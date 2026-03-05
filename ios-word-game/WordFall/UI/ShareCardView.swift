import SwiftUI
import UIKit

struct ShareCardView: View {
    static let exportSize = CGSize(width: 1080, height: 1350)

    let snapshot: RunSummarySnapshot

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF3F4F6),
                    Color(hex: 0xE6E8EC)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            decorativePattern

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(ParchmentTheme.Roguelike.Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .stroke(ParchmentTheme.Roguelike.Palette.tileStroke, lineWidth: 4)
                )
                .padding(84)
                .shadow(color: Color.black.opacity(0.12), radius: 34, x: 0, y: 20)

            VStack(spacing: 40) {
                header
                scoreBlock
                detailsBlock
            }
            .padding(.horizontal, 130)
            .padding(.vertical, 160)
        }
        .frame(width: ShareCardView.exportSize.width, height: ShareCardView.exportSize.height)
    }

    private var decorativePattern: some View {
        ZStack {
            Circle()
                .fill(ParchmentTheme.Roguelike.Palette.goldAccent.opacity(0.08))
                .frame(width: 460, height: 460)
                .offset(x: 350, y: -470)

            Circle()
                .fill(ParchmentTheme.Roguelike.Palette.darkButton.opacity(0.05))
                .frame(width: 420, height: 420)
                .offset(x: -370, y: 470)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Text("WordFall")
                .font(.system(size: 112, weight: .black, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("RUN SUMMARY")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.goldAccent)

            Text(snapshot.wonRun ? "Act 3 Complete" : "Run Ended")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)
        }
    }

    private var scoreBlock: some View {
        VStack(spacing: 10) {
            Text("TOTAL SCORE")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)

            Text("\(snapshot.totalScore)")
                .font(.system(size: 142, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.goldAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text("Boards Cleared \(snapshot.boardsProgressText)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textPrimary)
        }
    }

    private var detailsBlock: some View {
        VStack(spacing: 0) {
            detailRow(title: "Locks Broken", value: "\(snapshot.locksBroken)", emphasized: false)
            Divider().overlay(ParchmentTheme.Roguelike.Palette.tileStroke)
            detailRow(title: "Words Built", value: "\(snapshot.wordsBuilt)", emphasized: false)
            Divider().overlay(ParchmentTheme.Roguelike.Palette.tileStroke)
            detailRow(title: "Best Word", value: bestWordText, emphasized: true)
        }
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(ParchmentTheme.Roguelike.Palette.tileStroke, lineWidth: 3)
                )
        )
    }

    private func detailRow(title: String, value: String, emphasized: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(ParchmentTheme.Roguelike.Palette.textSecondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(emphasized
                    ? ParchmentTheme.Roguelike.Palette.goldAccent
                    : ParchmentTheme.Roguelike.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
    }

    private var bestWordText: String {
        guard !snapshot.bestWord.isEmpty else { return "—" }
        return "\(snapshot.bestWord.uppercased()) (\(snapshot.bestWordScore))"
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
            boardsCleared: 15,
            totalBoards: 15,
            boardReached: 15,
            locksBroken: 132,
            wordsBuilt: 247,
            bestWord: "REARRANGE",
            bestWordScore: 450
        )
    )
}
