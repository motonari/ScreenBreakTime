import AppKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: ScreenTimeMonitor
    @ObservedObject private var passcodeManager = PasscodeManager.shared

    @SwiftUI.State private var showDisablePrompt = false
    @SwiftUI.State private var showPasscodeSetup = false

    /// How long the forcible sleep is suspended when authorized.
    private let disableDuration: TimeInterval = 3 * 60 * 60

    var body: some View {
        VStack(spacing: 12) {
            Text("Remaining: \(iso8601String(for: monitor.remainingTime.duration))")
                .font(.title)

            Divider()

            if monitor.isSleepDisabled, let until = monitor.sleepDisabledUntil {
                Text("Sleep disabled until \(until, format: .dateTime.hour().minute())")
                    .foregroundStyle(.secondary)
                Button("Re-enable sleep") {
                    monitor.enableSleep()
                }
            } else {
                Button("Disable sleep for 3 hours") {
                    showDisablePrompt = true
                }
                .disabled(!passcodeManager.isSet)

                if !passcodeManager.isSet {
                    Text("Set a parent code to enable this.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button(passcodeManager.isSet ? "Change parent code" : "Set parent code") {
                showPasscodeSetup = true
            }
            .font(.caption)
        }
        .padding()
        .sheet(isPresented: $showDisablePrompt) {
            PasscodePromptView { code in
                guard passcodeManager.verify(code) else { return false }
                monitor.disableSleep(for: disableDuration)
                return true
            }
        }
        .sheet(isPresented: $showPasscodeSetup) {
            PasscodeSetupView()
        }
    }

    func iso8601String(for remainingTimeInterval: TimeInterval) -> String {
        let hours = Int(remainingTimeInterval) / 3600
        let minutes = Int(remainingTimeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(remainingTimeInterval.truncatingRemainder(dividingBy: 60))

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

/// Asks for the parent code before performing a privileged action.
///
/// `onSubmit` should return `true` when the code is accepted; the sheet
/// then dismisses itself. Returning `false` keeps the sheet open and
/// shows an error.
struct PasscodePromptView: View {
    let onSubmit: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @SwiftUI.State private var code = ""
    @SwiftUI.State private var showError = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Enter Parent Code")
                .font(.headline)

            SecureField("Parent code", text: $code)
                .textFieldStyle(.roundedBorder)

            if showError {
                Text("Incorrect code.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Confirm") {
                    if onSubmit(code) {
                        dismiss()
                    } else {
                        showError = true
                        code = ""
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(code.isEmpty)
            }
        }
        .padding()
        .frame(width: 260)
    }
}

/// Sets or changes the parent code. Changing an existing code requires
/// entering the current one first.
struct PasscodeSetupView: View {
    @ObservedObject private var passcodeManager = PasscodeManager.shared
    @Environment(\.dismiss) private var dismiss

    @SwiftUI.State private var currentCode = ""
    @SwiftUI.State private var newCode = ""
    @SwiftUI.State private var confirmCode = ""
    @SwiftUI.State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Text(passcodeManager.isSet ? "Change Parent Code" : "Set Parent Code")
                .font(.headline)

            if passcodeManager.isSet {
                SecureField("Current code", text: $currentCode)
                    .textFieldStyle(.roundedBorder)
            }
            SecureField("New code", text: $newCode)
                .textFieldStyle(.roundedBorder)
            SecureField("Confirm new code", text: $confirmCode)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func save() {
        if passcodeManager.isSet && !passcodeManager.verify(currentCode) {
            errorMessage = "Current code is incorrect."
            return
        }
        guard !newCode.isEmpty else {
            errorMessage = "New code cannot be empty."
            return
        }
        guard newCode == confirmCode else {
            errorMessage = "New codes do not match."
            return
        }
        passcodeManager.setPasscode(newCode)
        dismiss()
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeMonitor.shared)
}
