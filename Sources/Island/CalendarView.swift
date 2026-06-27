import SwiftUI

/// A compact month calendar. Shows the grid only (no events) with today
/// highlighted, weekends tinted, and prev/next month navigation. Names are shown
/// in English; the week start follows the system (`Calendar.current.firstWeekday`).
struct CalendarView: View {
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let displayLocale = Locale(identifier: "en_US")

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayHeader
            grid
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            navButton("chevron.left") { step(-1) }
            Spacer()
            // Tap the title to jump back to the current month.
            Text(monthTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { displayedMonth = Date() } }
            Spacer()
            navButton("chevron.right") { step(1) }
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday row

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day grid

    private var grid: some View {
        let cells = monthCells
        return VStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        dayCell(cells[row * 7 + column])
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let isToday = calendar.isDateInToday(date)
            let isWeekend = calendar.isDateInWeekend(date)
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundStyle(
                    isToday ? Color.black
                    : (isWeekend ? Color.red.opacity(0.85) : Color.white)
                )
                .frame(width: 26, height: 26)
                .background(Circle().fill(isToday ? Color.white : Color.clear))
        } else {
            Color.clear.frame(width: 26, height: 26)
        }
    }

    // MARK: - Data

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: displayedMonth)
    }

    /// English weekday symbols, reordered to start from the system's first weekday.
    private var orderedWeekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        let symbols = formatter.veryShortWeekdaySymbols ?? []
        guard symbols.count == 7 else { return symbols }
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// 42 cells (6 weeks) so the grid height never jumps between months.
    /// Leading/trailing slots outside the month are `nil`.
    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return Array(repeating: nil, count: 42)
        }
        let firstOfMonth = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        while cells.count < 42 { cells.append(nil) }
        return Array(cells.prefix(42))
    }

    private func step(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: displayedMonth) else { return }
        withAnimation { displayedMonth = next }
    }
}
