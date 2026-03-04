import Foundation
import Observation

@Observable
final class ToolkitViewModel {
    // GPA Calculator
    struct GPAEntry: Identifiable {
        let id = UUID()
        var courseName: String = ""
        var credits: Int = 3
        var gradePoint: Double = 4.0
    }

    var gpaEntries: [GPAEntry] = [GPAEntry()]

    var calculatedGPA: Double {
        let totalCredits = gpaEntries.reduce(0) { $0 + $1.credits }
        guard totalCredits > 0 else { return 0 }
        let weightedSum = gpaEntries.reduce(0.0) { $0 + Double($1.credits) * $1.gradePoint }
        return weightedSum / Double(totalCredits)
    }

    func addGPAEntry() {
        gpaEntries.append(GPAEntry())
    }

    func removeGPAEntry(at offsets: IndexSet) {
        gpaEntries.remove(atOffsets: offsets)
        if gpaEntries.isEmpty {
            gpaEntries.append(GPAEntry())
        }
    }

    // Pomodoro Timer
    var pomodoroMinutes: Int = 25
    var breakMinutes: Int = 5
    var isWorking: Bool = true
    var timeRemaining: Int = 25 * 60
    var isTimerRunning: Bool = false

    var timerProgress: Double {
        let total = isWorking ? pomodoroMinutes * 60 : breakMinutes * 60
        guard total > 0 else { return 0 }
        return 1.0 - Double(timeRemaining) / Double(total)
    }

    var timerDisplay: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func resetTimer() {
        isTimerRunning = false
        isWorking = true
        timeRemaining = pomodoroMinutes * 60
    }

    func toggleTimer() {
        isTimerRunning.toggle()
    }

    func tick() {
        guard isTimerRunning, timeRemaining > 0 else { return }
        timeRemaining -= 1
        if timeRemaining == 0 {
            isTimerRunning = false
            isWorking.toggle()
            timeRemaining = isWorking ? pomodoroMinutes * 60 : breakMinutes * 60
        }
    }
}
