import SwiftUI

/// The month progress bar with a marker for the expected usage by today.
struct MonthBarView: View {
    let usedFraction: Double
    let paceFraction: Double
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.quaternary)
                .frame(width: contentWidth, height: 8)
            Capsule()
                .fill(color)
                .frame(width: contentWidth * clamped(usedFraction), height: 8)
            RoundedRectangle(cornerRadius: 1)
                .fill(.primary)
                .frame(width: 2, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 1.5)
                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                        .frame(width: 4, height: 18)
                )
                .offset(x: contentWidth * clamped(paceFraction) - 1)
        }
        .frame(width: contentWidth, height: 16)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
