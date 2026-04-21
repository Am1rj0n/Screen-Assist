import SwiftUI

/// A native macOS Settings window, accessible via ⌘, from the menu bar
struct SettingsView: View {

    @StateObject private var state = DashboardState.shared
    @State private var tempKey: String = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            keysTab
                .tabItem { Label("API Keys", systemImage: "key") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 340)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Appearance") {
                HStack {
                    Text("Panel opacity")
                    Slider(value: $state.opacity, in: 0.15...1.0)
                    Text("\(Int(state.opacity * 100))%")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Defaults") {
                Picker("AI Provider", selection: $state.provider) {
                    ForEach(AIProvider.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }

                Picker("Model", selection: $state.model) {
                    ForEach(state.provider.models, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .onChange(of: state.provider) { _, _ in
                    state.model = state.provider.defaultModel
                }
            }

            Section("Keyboard Shortcuts") {
                LabeledContent("Show / Hide panel", value: "⌘ ⇧ Space")
                LabeledContent("Capture screen",    value: "⌘ ⇧ C")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - API Keys Tab

    private var keysTab: some View {
        Form {
            Section {
                Text("Keys are stored in macOS Keychain with device-only access. They are never written to disk or sent anywhere other than the selected AI provider.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(AIProvider.allCases) { p in
                Section(p.rawValue) {
                    KeyRowView(provider: p)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "viewfinder.circle.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundStyle(.primary)

            VStack(spacing: 4) {
                Text("ScreenAssist")
                    .font(.title2.weight(.semibold))
                Text("Version 1.0")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("A privacy-first screen capture assistant.\nCaptures only when you ask. Stores nothing.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 24) {
                Link("OpenAI Keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                Link("Claude Keys", destination: URL(string: "https://console.anthropic.com")!)
                Link("Gemini Keys", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Key Row

struct KeyRowView: View {
    let provider: AIProvider
    @State private var key: String = ""
    @State private var saved: Bool = false

    var body: some View {
        HStack {
            SecureField(provider.keyPlaceholder, text: $key)
                .onAppear { key = KeychainHelper.load(account: provider.keychainAccount) ?? "" }

            if !key.isEmpty {
                Button("Save") {
                    KeychainHelper.save(key, account: provider.keychainAccount)
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { saved = false }
                    }
                    // Sync to dashboard state if this is the active provider
                    if DashboardState.shared.provider == provider {
                        DashboardState.shared.apiKey = key
                    }
                }
                .foregroundStyle(saved ? .green : .accentColor)

                Button {
                    KeychainHelper.delete(account: provider.keychainAccount)
                    key = ""
                    if DashboardState.shared.provider == provider {
                        DashboardState.shared.apiKey = ""
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
