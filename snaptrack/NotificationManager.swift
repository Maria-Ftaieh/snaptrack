import Foundation
import UserNotifications

/// Schedules recurring "snapscore time" reminders for two-hour slots between
/// 10:00 and 00:00 inclusive. Each main notification gets a 10-minute follow-up
/// reminder unless the user opens the app first (which triggers a full
/// reschedule that drops the follow-up).
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let mainIdPrefix = "snaptrack.notif.main."
    private let reminderIdPrefix = "snaptrack.notif.reminder."

    /// 3 days × 8 slots × 2 (main+reminder) = 48 — under iOS's 64 pending limit.
    private let daysAhead = 3

    /// Slots between 10:00 and 00:00 (next-day midnight) every 2h.
    /// 0 means 00:00 of the next day; the scheduler handles the day rollover.
    private let slotHours = [10, 12, 14, 16, 18, 20, 22, 0]

    /// Call on every app foreground entry. Idempotent.
    func refresh() async {
        guard await requestAuthorizationIfNeeded() else { return }
        await rescheduleAll()
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func rescheduleAll() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)

        for dayOffset in 0..<daysAhead {
            for hour in slotHours {
                let realDayOffset = (hour == 0) ? dayOffset + 1 : dayOffset
                guard let baseDay = cal.date(byAdding: .day, value: realDayOffset, to: startOfToday),
                      let hourDate = cal.date(byAdding: .hour, value: hour, to: baseDay) else { continue }

                let minute = pseudoRandomMinute(for: hourDate, hour: hour)
                guard let scheduledDate = cal.date(byAdding: .minute, value: minute, to: hourDate),
                      scheduledDate > now else { continue }

                await scheduleMain(at: scheduledDate)
                if let reminderDate = cal.date(byAdding: .minute, value: 10, to: scheduledDate) {
                    await scheduleReminder(at: reminderDate, mainEpoch: Int(scheduledDate.timeIntervalSince1970))
                }
            }
        }
    }

    private func scheduleMain(at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Snapscore time"
        content.body = "Log your friends' scores."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "\(mainIdPrefix)\(Int(date.timeIntervalSince1970))"
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleReminder(at date: Date, mainEpoch: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Still waiting"
        content.body = "You haven't logged the snapscores yet — one tap is enough."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "\(reminderIdPrefix)\(mainEpoch)"
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Deterministic minute in 5...55 keyed on (year, month, day-of-year, hour),
    /// so the same slot keeps the same minute across reschedules within a day.
    private func pseudoRandomMinute(for date: Date, hour: Int) -> Int {
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .year, for: date) ?? 0
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        let raw = ((year &* 73) ^ (month &* 37) ^ (day &* 17) ^ (hour &* 5)) & 0x7FFFFFFF
        return (raw % 51) + 5
    }
}
