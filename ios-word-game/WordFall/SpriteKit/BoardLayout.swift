import CoreGraphics

struct BoardLayout {
    let rows: Int
    let cols: Int
    var spacing: CGFloat = 6
    var padding: CGFloat = 18

    private(set) var tileSize: CGFloat = 42
    private(set) var boardSize: CGSize = .zero

    mutating func update(sceneSize: CGSize) {
        let minDimension = min(sceneSize.width, sceneSize.height)
        let usable = max(220, minDimension - (padding * 2))
        let totalSpacing = spacing * CGFloat(cols - 1)
        tileSize = floor((usable - totalSpacing) / CGFloat(cols))
        let side = (tileSize * CGFloat(cols)) + totalSpacing
        boardSize = CGSize(width: side, height: side)
    }

    func position(for index: Int) -> CGPoint {
        let row = index / cols
        let col = index % cols
        let pitch = tileSize + spacing

        let left = -boardSize.width / 2
        let top = boardSize.height / 2

        let x = left + (CGFloat(col) * pitch) + (tileSize / 2)
        let y = top - (CGFloat(row) * pitch) - (tileSize / 2)
        return CGPoint(x: x, y: y)
    }

    func index(at point: CGPoint) -> Int? {
        let pitch = tileSize + spacing
        let left = -boardSize.width / 2
        let top = boardSize.height / 2

        let colFloat = (point.x - left) / pitch
        let rowFloat = (top - point.y) / pitch

        let col = Int(floor(colFloat))
        let row = Int(floor(rowFloat))

        guard row >= 0, row < rows, col >= 0, col < cols else {
            return nil
        }

        return row * cols + col
    }
}
