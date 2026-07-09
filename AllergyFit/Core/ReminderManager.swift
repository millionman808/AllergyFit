import Foundation
import UserNotifications

/// Local meal/check-in reminders via UNUserNotificationCenter.
@MainActor
final class ReminderManager: ObservableObject {
    @Published var authorized = false
    @Published var mealRemindersOn = UserDefaults.standard.bool(forKey: "reminder.meals")
    @Published var symptomReminderOn = UserDefaults.standard.bool(forKey: "reminder.symptom")

    private let center = UNUserNotificationCenter.current()

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Returns true if permission is granted (requesting it if needed).
    @discardableResult
    func ensureAuthorized() async -> Bool {
        await refreshStatus()
        if authorized { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorized = granted
        return granted
    }

    func setMealReminders(_ on: Bool) async {
        mealRemindersOn = on
        UserDefaults.standard.set(on, forKey: "reminder.meals")
        guard on else { removeMealReminders(); return }
        guard await ensureAuthorized() else { mealRemindersOn = false; UserDefaults.standard.set(false, forKey: "reminder.meals"); return }
        schedule(id: "meal.breakfast", title: "Log your breakfast", body: "Keep your safe-eating streak going.", hour: 9, minute: 0)
        schedule(id: "meal.lunch", title: "Log your lunch", body: "A quick tap keeps your macros on track.", hour: 13, minute: 0)
        schedule(id: "meal.dinner", title: "Log your dinner", body: "Wrap up your day of safe fueling.", hour: 19, minute: 30)
    }

    func setSymptomReminder(_ on: Bool) async {
        symptomReminderOn = on
        UserDefaults.standard.set(on, forKey: "reminder.symptom")
        guard on else { center.removePendingNotificationRequests(withIdentifiers: ["checkin.symptom"]); return }
        guard await ensureAuthorized() else { symptomReminderOn = false; UserDefaults.standard.set(false, forKey: "reminder.symptom"); return }
        schedule(id: "checkin.symptom", title: "How are you feeling?", body: "A 30-second check-in helps AllergyFit spot patterns.", hour: 20, minute: 30)
    }

    private func removeMealReminders() {
        center.removePendingNotificationRequests(withIdentifiers: ["meal.breakfast", "meal.lunch", "meal.dinner"])
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
