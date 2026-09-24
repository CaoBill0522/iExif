import SwiftUI

@main
struct ExifEditorApp: App {
    @State private var templates = TemplateStore()
    @State private var browser = PhotoLibraryBrowser()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(templates)
                .environment(browser)
        }
    }
}

struct RootTabView: View {
    enum Tab: String {
        case edit, templates, settings
    }

    @SceneStorage("selectedTab") private var selection: Tab = .edit
    @AppStorage(OnboardingKey.seen) private var onboardingSeen = false

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Edit", systemImage: "photo.on.rectangle.angled") }
                .tag(Tab.edit)
            TemplatesView()
                .tabItem { Label("Templates", systemImage: "square.stack") }
                .tag(Tab.templates)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .fullScreenCover(isPresented: Binding(get: { !onboardingSeen }, set: { if !$0 { onboardingSeen = true } })) {
            OnboardingView()
        }
    }
}
