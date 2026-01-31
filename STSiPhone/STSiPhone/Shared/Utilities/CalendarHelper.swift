import Foundation
import EventKit

public enum CalendarHelper {
    
    /// Add an event to the user's default calendar
    public static func addEvent(
        title: String,
        date: Date,
        duration: TimeInterval = 3600, // 1 hour default
        location: String? = nil,
        notes: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let store = EKEventStore()
        
        // Request access to calendar
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    guard granted else {
                        completion(false, "Calendar access denied. Please enable in Settings.")
                        return
                    }
                    
                    guard error == nil else {
                        completion(false, "Calendar access error: \(error?.localizedDescription ?? "Unknown")")
                        return
                    }
                    
                    createAndSaveEvent()
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    guard granted else {
                        completion(false, "Calendar access denied. Please enable in Settings.")
                        return
                    }
                    
                    guard error == nil else {
                        completion(false, "Calendar access error: \(error?.localizedDescription ?? "Unknown")")
                        return
                    }
                    
                    createAndSaveEvent()
                }
            }
        }
        
        func createAndSaveEvent() {
            // Create the event
            let event = EKEvent(eventStore: store)
            event.title = title
            event.startDate = date
            event.endDate = date.addingTimeInterval(duration)
            event.notes = notes
            
            if let location = location {
                event.location = location
            }
            
            // Add to default calendar
            event.calendar = store.defaultCalendarForNewEvents
            
            // Save the event
            do {
                try store.save(event, span: .thisEvent)
                completion(true, "Event added to calendar successfully")
                print("✅ Calendar event created: \(title) at \(date)")
            } catch {
                completion(false, "Failed to save event: \(error.localizedDescription)")
                print("❌ Calendar save error: \(error)")
            }
        }
    }
    
    /// Create a formatted audition event
    public static func addAuditionEvent(
        projectTitle: String,
        roleName: String?,
        sessionType: SessionType,
        date: Date,
        location: String? = nil,
        address: String? = nil,
        parkingInfo: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let eventTitle: String
        if let role = roleName, !role.isEmpty {
            eventTitle = "Audition: \(projectTitle) - \(role)"
        } else {
            eventTitle = "Audition: \(projectTitle)"
        }
        
        var eventNotes = "Session Type: \(sessionType.rawValue)"
        
        if let parking = parkingInfo, !parking.isEmpty {
            eventNotes += "\n\nParking: \(parking)"
        }
        
        eventNotes += "\n\nCreated by Self Tape Studio"
        
        let eventLocation: String?
        if let address = address, !address.isEmpty {
            eventLocation = address
        } else {
            eventLocation = location
        }
        
        addEvent(
            title: eventTitle,
            date: date,
            location: eventLocation,
            notes: eventNotes,
            completion: completion
        )
    }
    
    /// Check if calendar access is available
    public static func checkCalendarAccess() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }
}
