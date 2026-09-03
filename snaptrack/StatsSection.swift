import Charts
import SwiftUI

struct StatsSection: View {
    let stats: Stats

    var body: some View {
        VStack(spacing: 16) {
            metricsGrid
            if !stats.timeSeries.isEmpty {
                timeSeriesChart
            }
            if !stats.dailyActivity.isEmpty {
                dailyChart
            }
            if !stats.weeklyActivity.isEmpty {
                weeklyChart
            }
            if stats.hourlyActivity.contains(where: { $0.avgSnapsPerHour > 0 }) {
                hourlyChart
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "Last 7 days",
                       value: stats.last7Days.map { "+\($0.delta.formatted())" } ?? "—",
                       sub: stats.last7Days.map { String(format: "%.1f/day", $0.dailyAvg) })
            MetricCard(title: "Last 30 days",
                       value: stats.last30Days.map { "+\($0.delta.formatted())" } ?? "—",
                       sub: stats.last30Days.map { String(format: "%.1f/day", $0.dailyAvg) })
            MetricCard(title: "This week vs last",
                       value: percentDisplay(stats.weekOverWeekPct),
                       sub: nil,
                       tone: tone(stats.weekOverWeekPct))
            MetricCard(title: "This month vs last",
                       value: percentDisplay(stats.monthOverMonthPct),
                       sub: nil,
                       tone: tone(stats.monthOverMonthPct))
        }
    }

    private var timeSeriesDomain: ClosedRange<Int> {
        let scores = stats.timeSeries.map(\.score)
        guard let lo = scores.min(), let hi = scores.max() else { return 0...1 }
        let span = max(hi - lo, 1)
        let pad = max(span / 10, 1)
        return (lo - pad)...(hi + pad)
    }

    private var timeSeriesChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Snapscore (last 30 days)").font(.headline)
            Chart(stats.timeSeries) { pt in
                LineMark(x: .value("Time", pt.t), y: .value("Score", pt.score))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Time", pt.t), y: .value("Score", pt.score))
                    .symbolSize(20)
            }
            .chartYScale(domain: timeSeriesDomain)
            .frame(height: 200)
        }
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily activity (last 14 days)").font(.headline)
            Chart(stats.dailyActivity) { d in
                BarMark(
                    x: .value("Day", d.date, unit: .day),
                    y: .value("Snap", d.snaps)
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weekly activity (last 8 weeks)").font(.headline)
            Chart(stats.weeklyActivity) { w in
                BarMark(
                    x: .value("Week", w.weekStart, unit: .weekOfYear),
                    y: .value("Snap", w.snaps)
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 1)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
        }
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hourly activity (snaps/hour)").font(.headline)
            Chart(stats.hourlyActivity) { b in
                BarMark(x: .value("Hour", b.hour), y: .value("Snaps/hour", b.avgSnapsPerHour))
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23])
            }
            .frame(height: 160)
        }
    }

    private func percentDisplay(_ v: Double?) -> String {
        guard let v else { return "—" }
        let sign = v > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", v))%"
    }

    private func tone(_ v: Double?) -> MetricCard.Tone {
        guard let v else { return .neutral }
        if v > 0 { return .positive }
        if v < 0 { return .negative }
        return .neutral
    }
}

private struct MetricCard: View {
    enum Tone { case neutral, positive, negative }

    let title: String
    let value: String
    var sub: String? = nil
    var tone: Tone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            if let s = sub {
                Text(s).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var color: Color {
        switch tone {
        case .neutral: return .primary
        case .positive: return .green
        case .negative: return .red
        }
    }
}
