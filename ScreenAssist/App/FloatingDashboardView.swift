import SwiftUI

// MARK: - AI Provider

enum AIProvider: String, CaseIterable, Identifiable {
    case openai = "ChatGPT"
    case claude = "Claude"
    case gemini = "Gemini"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .openai: return Color(red: 0.29, green: 0.82, blue: 0.62)
        case .claude: return Color(red: 0.96, green: 0.58, blue: 0.22)
        case .gemini: return Color(red: 0.33, green: 0.60, blue: 0.98)
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-proj-... or sk-..."
        case .claude: return "sk-ant-..."
        case .gemini: return "AIza..."
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o"
        case .claude: return "claude-haiku-4-5-20251001"
        case .gemini: return "gemini-2.5-flash-lite"
        }
    }

    var models: [String] {
        switch self {
            
        case .openai: return [
            "gpt-4o-mini",
            "gpt-4o",
            "gpt-4.1"
        ]
        case .claude: return [
            "claude-haiku-4-5-20251001",
            "claude-sonnet-4-6",
            "claude-opus-4-6"
        ]
        case .gemini: return [
            "gemini-2.5-flash-lite",
            "gemini-2.5-flash",
            "gemini-2.5-pro"
        ]
        }
    }

    var keychainAccount: String { "sa-key-\(rawValue.lowercased())" }
}

// MARK: - Shared App State

class DashboardState: ObservableObject {
    static let shared = DashboardState()
    private init() {}

    @Published var provider:   AIProvider = .openai
    @Published var model:      String     = AIProvider.openai.defaultModel
    @Published var opacity:    Double     = 0.90
    @Published var isExpanded: Bool       = false
    @Published var response:   String     = ""
    @Published var isLoading:  Bool       = false
    @Published var status:     String     = "Ready - Cmd+Shift+C to capture"
    @Published var apiKey:     String     = ""
    @Published var prompt:     String     = ""
    @Published var copyDone:   Bool       = false

    func loadKey() {
        apiKey = KeychainHelper.load(account: provider.keychainAccount) ?? ""
    }

    func saveKey() {
        KeychainHelper.save(apiKey, account: provider.keychainAccount)
        status = "Key saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.status = "Ready - Cmd+Shift+C to capture"
        }
    }
}

// MARK: - Main View

struct FloatingDashboardView: View {

    weak var appDelegate: AppDelegate?
    @StateObject private var state = DashboardState.shared

    private let collapsedH: CGFloat = 58
    private let expandedH:  CGFloat = 480

    private let capturer = ScreenCapturer()
    private let ocr      = OCRProcessor()
    private let ai       = AIClient()

    var body: some View {
        ZStack(alignment: .top) {
            glassBackground
            VStack(spacing: 0) {
                topBar
                if state.isExpanded {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal:   .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
        }
        .frame(width: 360)
        .frame(height: state.isExpanded ? expandedH : collapsedH)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(glowBorder)
        .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 10)
        .opacity(state.opacity)
        .animation(.spring(response: 0.38, dampingFraction: 0.80), value: state.isExpanded)
        .onAppear { state.loadKey() }
        .onChange(of: state.provider) { _, _ in
            state.model = state.provider.defaultModel
            state.loadKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerCapture)) { _ in
            Task { await runCapture() }
        }
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            Color.black.opacity(0.82)
            LinearGradient(
                colors: [Color.white.opacity(0.09), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.35)
            )
            if state.isLoading {
                state.provider.accentColor.opacity(0.05)
            }
            Color.white.opacity(0.012)
        }
        .background(.ultraThinMaterial.opacity(0.18))
    }

    private var glowBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.7
            )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 11) {
            captureDotButton
            statusBlock
            Slider(value: $state.opacity, in: 0.15...1.0)
                .frame(width: 56)
                .tint(Color.white.opacity(0.35))
                .help("Adjust panel opacity")
            expandButton
        }
        .padding(.horizontal, 13)
        .frame(height: collapsedH)
    }

    private var captureDotButton: some View {
        Button {
            Task { await runCapture() }
        } label: {
            ZStack {
                Circle()
                    .fill(state.isLoading
                          ? state.provider.accentColor.opacity(0.18)
                          : Color.white.opacity(0.11))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().stroke(
                            state.provider.accentColor.opacity(state.isLoading ? 0.6 : 0.0),
                            lineWidth: 1.2
                        )
                    )
                if state.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.55)
                        .tint(state.provider.accentColor)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state.isLoading)
        .help("Capture screen (Cmd+Shift+C)")
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if state.response.isEmpty || state.isLoading {
                Text(state.status)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)
            } else {
                Text(state.response)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(state.provider.accentColor)
                    .frame(width: 5, height: 5)
                Text(state.provider.rawValue + " - " + state.model)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expandButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                state.isExpanded.toggle()
            }
            appDelegate?.resizePanel(to: state.isExpanded ? expandedH : collapsedH)
        } label: {
            Image(systemName: state.isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.40))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(state.isExpanded ? "Collapse" : "Expand")
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    providerSection
                    thinLine
                    promptSection
                    bigCaptureButton
                    if !state.response.isEmpty {
                        responseSection
                    }
                    thinLine
                    opacitySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("AI PROVIDER")

            HStack(spacing: 6) {
                ForEach(AIProvider.allCases) { p in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.provider = p
                        }
                    } label: {
                        Text(p.rawValue)
                            .font(.system(
                                size: 11.5,
                                weight: state.provider == p ? .semibold : .regular,
                                design: .rounded
                            ))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                state.provider == p
                                    ? p.accentColor.opacity(0.22)
                                    : Color.white.opacity(0.05)
                            )
                            .foregroundStyle(
                                state.provider == p
                                    ? p.accentColor
                                    : Color.white.opacity(0.38)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(
                                        state.provider == p
                                            ? p.accentColor.opacity(0.50)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 0.6
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.25))
                Picker("", selection: $state.model) {
                    ForEach(state.provider.models, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11.5))
                .tint(Color.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            apiKeyField
        }
    }

    // MARK: - API Key Field

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: state.apiKey.isEmpty ? "key" : "key.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(
                        state.apiKey.isEmpty
                            ? Color.orange.opacity(0.85)
                            : state.provider.accentColor.opacity(0.75)
                    )
                SecureField(state.provider.keyPlaceholder, text: $state.apiKey)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .textFieldStyle(.plain)
                    .onSubmit { state.saveKey() }
                if !state.apiKey.isEmpty {
                    Button("Save") { state.saveKey() }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(state.provider.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(state.provider.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .buttonStyle(.plain)
                }
            }
            .padding(9)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        state.apiKey.isEmpty
                            ? Color.orange.opacity(0.35)
                            : Color.white.opacity(0.07),
                        lineWidth: 0.6
                    )
            )
            Text("Stored in macOS Keychain - never saved to disk")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.18))
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("QUESTION (optional)")
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.22))
                TextField("e.g. What language is this code?", text: $state.prompt)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .textFieldStyle(.plain)
            }
            .padding(9)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
            )
        }
    }

    // MARK: - Big Capture Button

    private var bigCaptureButton: some View {
        Button {
            Task { await runCapture() }
        } label: {
            HStack(spacing: 9) {
                if state.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.60)
                        .tint(Color.black.opacity(0.7))
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(state.isLoading ? "Analyzing..." : "Capture & Analyze")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                state.isLoading
                    ? state.provider.accentColor.opacity(0.25)
                    : state.provider.accentColor.opacity(0.90)
            )
            .foregroundStyle(state.isLoading ? state.provider.accentColor : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: state.isLoading)
        }
        .buttonStyle(.plain)
        .disabled(state.isLoading || state.apiKey.isEmpty)
        .help(state.apiKey.isEmpty ? "Enter your API key above first" : "Capture screen (Cmd+Shift+C)")
    }

    // MARK: - Response Section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                sectionLabel("RESPONSE")
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.response, forType: .string)
                    withAnimation { state.copyDone = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { state.copyDone = false }
                    }
                } label: {
                    Label(
                        state.copyDone ? "Copied!" : "Copy",
                        systemImage: state.copyDone ? "checkmark" : "doc.on.doc"
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        state.copyDone
                            ? state.provider.accentColor
                            : Color.white.opacity(0.30)
                    )
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                Text(state.response)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
            }
            .frame(maxHeight: 130)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(state.provider.accentColor.opacity(0.20), lineWidth: 0.6)
            )
        }
    }

    // MARK: - Opacity Section

    private var opacitySection: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.22))
            Text("Opacity")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.28))
            Slider(value: $state.opacity, in: 0.15...1.0)
                .tint(Color.white.opacity(0.35))
            Text("\(Int(state.opacity * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.28))
                .frame(width: 34, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.28))
            .tracking(1.1)
    }

    private var thinLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }

    // MARK: - Capture Pipeline

    @MainActor
    func runCapture() async {
        guard !state.apiKey.isEmpty else {
            withAnimation { state.isExpanded = true }
            appDelegate?.resizePanel(to: expandedH)
            state.status = "Enter your API key first"
            return
        }

        state.isLoading = true
        state.response  = ""
        state.status    = "Capturing..."

        appDelegate?.floatingPanel?.orderOut(nil)
        try? await Task.sleep(nanoseconds: 280_000_000)

        do {
            guard let image = await capturer.captureScreen() else {
                throw SAError.captureFailure
            }
            appDelegate?.floatingPanel?.makeKeyAndOrderFront(nil)

            state.status = "Reading text..."
            let text = try await ocr.extractText(from: image)
            guard !text.isEmpty else { throw SAError.noText }

            state.status = "Asking \(state.provider.rawValue)..."
            let question = state.prompt.isEmpty
                ? "what do you see on the screen and if theres something needed to be solved, do it."
                : state.prompt

            state.response = try await ai.ask(
                question: question,
                context:  text,
                apiKey:   state.apiKey,
                provider: state.provider,
                model:    state.model
            )
            state.status = "Done"

            if !state.isExpanded {
                withAnimation { state.isExpanded = true }
                appDelegate?.resizePanel(to: expandedH)
            }

        } catch SAError.captureFailure {
            appDelegate?.floatingPanel?.makeKeyAndOrderFront(nil)
            state.response = "Screen capture failed.\n\nFix: System Settings > Privacy & Security > Screen Recording > enable ScreenAssist, then relaunch."
            state.status   = "Permission needed"
            if !state.isExpanded {
                withAnimation { state.isExpanded = true }
                appDelegate?.resizePanel(to: expandedH)
            }
        } catch SAError.noText {
            appDelegate?.floatingPanel?.makeKeyAndOrderFront(nil)
            state.response = "No readable text found on screen."
            state.status   = "No text detected"
        } catch {
            appDelegate?.floatingPanel?.makeKeyAndOrderFront(nil)
            state.response = "Error: \(error.localizedDescription)"
            state.status   = "Error"
        }

        state.isLoading = false
    }
}

// MARK: - Errors

enum SAError: Error {
    case captureFailure
    case noText
}
