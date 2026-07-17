import SwiftUI
import Charts

/// Kept+ only. Real numbers computed from actual check-in history, not placeholder
/// content — this was advertised on the paywall with nothing behind it before now.
struct StreakInsightsView: View {
    @EnvironmentObject var appModel: AppModel

    private var calendar: DayCalendar { appModel.dayCalendar }

    private var totalCheckIns: Int {
        appModel.habits.reduce(0) { $0 + $1.checkInHistory.count }
    }

    private var bestStreakEver: Int {
        appModel.habits.map { $0.longestStreak(calendar: calendar) }.max() ?? 0
    }

    /// Share of days, since your oldest habit started, where you checked in on at least
    /// one thing — the same "did you show up" idea as the combined streak, but as a
    /// percentage over your whole history instead of just the current run.
    private var consistencyRate: Int {
        guard let oldestStart = appModel.habits.map(\.createdAt).min() else { return 0 }
        let totalDays = max(1, calendar.daysBetween(oldestStart, Date()) + 1)
        let activeDays = Set(appModel.habits.flatMap(\.checkInHistory).map { calendar.logicalDay(for: $0) }).count
        return min(100, Int((Double(activeDays) / Double(totalDays) * 100).rounded()))
    }

    /// Check-ins per day, last 30 days, across every habit — the shape of your
    /// consistency at a glance, not just a single number.
    private var last30Days: [(date: Date, count: Int)] {
        let today = calendar.logicalDay(for: Date())
        let allCheckIns = appModel.habits.flatMap(\.checkInHistory).map { calendar.logicalDay(for: $0) }
        return (0..<30).reversed().compactMap { offset -> (Date, Int)? in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = allCheckIns.filter { $0 == day }.count
            return (day, count)
        }
    }

    var body: some View {
        Group {
            if appModel.isSubscribed {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Streak insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var unlockedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statRow
                chartCard
                perHabitCard
            }
            .padding(22)
            .padding(.bottom, 90)
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            statTile(value: "\(bestStreakEver)", label: "Best streak")
            statTile(value: "\(totalCheckIns)", label: "Total check-ins")
            statTile(value: "\(consistencyRate)%", label: "Consistency")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(KeptFont.mono(20, weight: .semibold)).foregroundStyle(.keptInk)
            Text(label.uppercased())
                .font(KeptFont.body(9.5, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 30 DAYS")
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptInkSoft)

            Chart(last30Days, id: \.date) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Check-ins", entry.count)
                )
                .foregroundStyle(entry.count > 0 ? Color.keptOrange : Color.keptLine)
                .cornerRadius(2)
            }
            .frame(height: 140)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding(18)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))
    }

    private var perHabitCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BY HABIT")
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(appModel.habits) { habit in
                    HStack {
                        Text(habit.name)
                            .font(KeptFont.body(13.5, weight: .semibold))
                            .foregroundStyle(.keptInk)
                        Spacer()
                        Text("best \(habit.longestStreak(calendar: calendar))")
                            .font(KeptFont.mono(11.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
                }
            }
            .background(.keptSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("STREAK INSIGHTS")
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptPurpleDeep)
            Text("See your best runs, total check-ins, and 30-day consistency across every habit.")
                .font(KeptFont.display(19, weight: .semibold))
                .foregroundStyle(.keptInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Button("Unlock with Kept+") { appModel.selectedTab = .paywall }
                .buttonStyle(.keptPrimary)
                .padding(.horizontal, 40)
                .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(22)
    }
}
