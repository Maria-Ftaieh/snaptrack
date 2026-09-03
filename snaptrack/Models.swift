import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let snapchatUsername: String?
    let createdAt: Date
    let latestScore: Int?
    let latestRecordedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case snapchatUsername = "snapchat_username"
        case createdAt = "created_at"
        case latestScore = "latest_score"
        case latestRecordedAt = "latest_recorded_at"
    }
}

struct ScoreLog: Identifiable, Codable, Hashable {
    let id: Int
    let userId: Int
    let score: Int
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, score
        case userId = "user_id"
        case recordedAt = "recorded_at"
    }
}

struct PeriodStats: Codable, Hashable {
    let delta: Int
    let dailyAvg: Double
    let periodStart: Date
    let periodEnd: Date

    enum CodingKeys: String, CodingKey {
        case delta
        case dailyAvg = "daily_avg"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

struct TimeSeriesPoint: Codable, Hashable, Identifiable {
    let t: Date
    let score: Int
    var id: Date { t }
}

struct HourlyBucket: Codable, Hashable, Identifiable {
    let hour: Int
    let avgSnapsPerHour: Double
    var id: Int { hour }

    enum CodingKeys: String, CodingKey {
        case hour
        case avgSnapsPerHour = "avg_snaps_per_hour"
    }
}

struct DailyActivity: Codable, Hashable, Identifiable {
    let date: Date
    let snaps: Int
    var id: Date { date }
}

struct WeeklyActivity: Codable, Hashable, Identifiable {
    let weekStart: Date
    let snaps: Int
    var id: Date { weekStart }

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case snaps
    }
}

struct Stats: Codable, Hashable {
    let currentScore: Int?
    let lastRecordedAt: Date?
    let last7Days: PeriodStats?
    let last30Days: PeriodStats?
    let weekOverWeekPct: Double?
    let monthOverMonthPct: Double?
    let timeSeries: [TimeSeriesPoint]
    let hourlyActivity: [HourlyBucket]
    let dailyActivity: [DailyActivity]
    let weeklyActivity: [WeeklyActivity]

    enum CodingKeys: String, CodingKey {
        case currentScore = "current_score"
        case lastRecordedAt = "last_recorded_at"
        case last7Days = "last_7_days"
        case last30Days = "last_30_days"
        case weekOverWeekPct = "week_over_week_pct"
        case monthOverMonthPct = "month_over_month_pct"
        case timeSeries = "time_series"
        case hourlyActivity = "hourly_activity"
        case dailyActivity = "daily_activity"
        case weeklyActivity = "weekly_activity"
    }
}

struct CreateUserRequest: Codable {
    let name: String
    let snapchatUsername: String?

    enum CodingKeys: String, CodingKey {
        case name
        case snapchatUsername = "snapchat_username"
    }
}

struct CreateScoreRequest: Codable {
    let score: Int
    let recordedAt: Date?

    enum CodingKeys: String, CodingKey {
        case score
        case recordedAt = "recorded_at"
    }
}
