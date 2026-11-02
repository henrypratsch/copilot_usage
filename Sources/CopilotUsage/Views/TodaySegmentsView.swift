import SwiftUI

/// Today's budget as ten segments.
struct TodaySegmentsView: View {
    /// `usedToday / dailyBudget`, clamped to 0…1.
    let fraction: Double
    let color: Color
    /// Dims the segments on days off.
    var disabled = false

    private let count = 10
    private let gap: CGFloat = 3
    private let height: CGFloat = 14

    private var segmentWidth: CGFloat {
        (contentWidth - CGFloat(count - 1) * gap) / CGFloat(count)
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<count, id: \.self) { index in
                let fill = Self.segmentFill(index: index, fraction: fraction, count: count)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(.quaternary)
                    if fill > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(disabled ? Color.secondary.opacity(0.5) : color)
                            .frame(width: segmentWidth * fill)
                    }
                }
                .frame(width: segmentWidth, height: height)
            }
        }
        .frame(width: contentWidth, height: height)
    }

    /// How much of segment `index` is filled, 0…1.
    static func segmentFill(index: Int, fraction: Double, count: Int) -> Double {
        let filled = min(max(fraction, 0), 1) * Double(count)
        return min(max(filled - Double(index), 0), 1)
    }
}
