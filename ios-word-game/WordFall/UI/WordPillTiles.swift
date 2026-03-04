import SwiftUI

/// Renders the current selection as a row of mini parchment-style letter tiles.
///
/// Drop this into the word-feedback pill in place of the plain `Text` word display.
/// - When `letters` is empty it shows the "Tap letters to spell" placeholder.
/// - Wildcards show "?" in purple tint.
/// - `freshLocked` tiles show a small lock badge in the top-right corner.
///
/// Sizing / spacing tunables live in `WordFeedbackStyle.MiniTile`.
struct WordPillTiles: View {
    /// Characters to render, one tile each. Use "?" for wildcard display.
    let letters: [Character]
    /// Optional per-letter metadata aligned to `letters`. Pass `nil` to skip badges.
    let tileMeta: [SelectionTileMeta]?

    var body: some View {
        if letters.isEmpty {
            Text("Tap letters to spell")
                .font(.parchmentRounded(size: 21, weight: .heavy))
                .foregroundStyle(ParchmentTheme.Palette.slate)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        } else {
            HStack(spacing: WordFeedbackStyle.MiniTile.spacing) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    miniTile(letter: letter, meta: tileMeta?[safe: index])
                }
            }
        }
    }

    @ViewBuilder
    private func miniTile(letter: Character, meta: SelectionTileMeta?) -> some View {
        let isWildcard = meta?.isWildcard ?? (letter == "?")
        let isLocked   = meta?.freshness == .freshLocked
        let S          = WordFeedbackStyle.MiniTile.self

        ZStack(alignment: .topTrailing) {
            // Tile body
            ZStack {
                RoundedRectangle(cornerRadius: S.cornerRadius, style: .continuous)
                    .fill(ParchmentTheme.Palette.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: S.cornerRadius, style: .continuous)
                            .stroke(ParchmentTheme.Palette.ink, lineWidth: S.strokeWidth)
                    )
                    .shadow(
                        color: ParchmentTheme.Palette.ink.opacity(0.22),
                        radius: 0,
                        x: 0,
                        y: S.shadowY
                    )

                Text(isWildcard ? "?" : String(letter).uppercased())
                    .font(.parchmentRounded(size: 15, weight: .heavy))
                    .foregroundStyle(
                        isWildcard
                            ? ParchmentTheme.Palette.footerPurple
                            : ParchmentTheme.Palette.ink
                    )
            }
            .frame(width: S.size, height: S.size)

            // Lock badge (top-right corner)
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(2.5)
                    .background(
                        Circle()
                            .fill(ParchmentTheme.Palette.footerRed)
                    )
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Safe subscript (file-private to avoid conflicts)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
