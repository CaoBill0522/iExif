import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var showOnboarding = false
    @AppStorage(SettingsKey.saveMode) private var saveMode: SaveMode = .saveAsNew
    @AppStorage(SettingsKey.stripMakerNote) private var stripMakerNote = false
    @AppStorage(SettingsKey.outputFormat) private var outputFormat: OutputFormatMode = .followDevice
    @AppStorage(SettingsKey.matchResolution) private var matchResolution = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Default Save Mode", selection: $saveMode) {
                        ForEach(SaveMode.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Remove MakerNote by Default", isOn: $stripMakerNote)
                    Toggle("Match Device Resolution by Default", isOn: $matchResolution)
                } header: {
                    Text("Saving")
                } footer: {
                    Text("You can still change these each time you save.")
                }

                Section {
                    Picker("Output Format", selection: $outputFormat) {
                        ForEach(OutputFormatMode.allCases) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text(outputFormat == .followDevice
                         ? "Photos are saved as HEIC for iPhone 7 and later, and as JPEG for older devices. Converting re-encodes the image."
                         : "The original format is kept unless the chosen device couldn't have taken it, such as HEIC on an iPhone 6s or any PNG.")
                }

                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Feature Tour", systemImage: "sparkles")
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("Language & Permissions", systemImage: "globe")
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                } footer: {
                    Text("All photos are processed on your device. Nothing is uploaded.")
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
