import Foundation

struct SlateConfiguration: Codable, Equatable {
    var reminderTitle: String
    var reminderMessage: String
    var reminderCTA: String

    init(
        reminderTitle: String = "Slate Reminder",
        reminderMessage: String = "State your name, role, and representation before each slate.",
        reminderCTA: String = "Let’s Go"
    ) {
        self.reminderTitle = reminderTitle
        self.reminderMessage = reminderMessage
        self.reminderCTA = reminderCTA
    }
}
