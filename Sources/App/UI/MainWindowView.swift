import SwiftUI

// MARK: - Brand palette (from icon gradient)

private extension Color {
    static let brandCyan = Color(red: 0.0, green: 0.85, blue: 0.95)
    static let brandGreen = Color(red: 0.3, green: 0.95, blue: 0.4)
    static let brandYellow = Color(red: 1.0, green: 0.85, blue: 0.1)
    static let brandPink = Color(red: 1.0, green: 0.3, blue: 0.6)

    // Dark surface colors
    static let surfaceBase = Color(red: 0.07, green: 0.07, blue: 0.08)       // #121214 main bg
    static let surfaceSidebar = Color(red: 0.09, green: 0.09, blue: 0.10)    // #171719 sidebar
    static let surfaceCard = Color(red: 0.11, green: 0.11, blue: 0.13)       // #1c1c21 cards
    static let surfaceInput = Color(red: 0.14, green: 0.14, blue: 0.16)      // #242429 inputs
}

private let brandGradient = LinearGradient(
    colors: [.brandCyan, .brandGreen, .brandYellow, .brandPink],
    startPoint: .leading,
    endPoint: .trailing
)

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    @State private var selectedTab: SidebarTab = .settings
    @State private var isRecordingShortcut = false
    @State private var availableDevices: [AudioDevice] = []
    @State private var searchText = ""
    @State private var displayLimit = 10
    @State private var sidebarCollapsed = false
    @State private var isEditingAPIKey = false
    @ObservedObject private var usageTracker = UsageTracker.shared

    private enum SidebarTab: String, CaseIterable, Identifiable {
        case settings = "Settings"
        case transcripts = "Transcripts"
        case permissions = "Permissions"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .settings: "gearshape"
            case .transcripts: "text.bubble"
            case .permissions: "lock.shield"
            }
        }
    }

    private func refreshMicrophoneList() {
        availableDevices = AudioDevice.inputDevices()
        if let uid = settings.selectedMicrophoneUID,
           !availableDevices.contains(where: { $0.uid == uid }) {
            settings.selectedMicrophoneUID = nil
        }
    }

    private var maskedAPIKey: String {
        let key = settings.assemblyAIKey
        if key.count <= 8 { return String(repeating: "\u{2022}", count: key.count) }
        return key.prefix(4) + String(repeating: "\u{2022}", count: key.count - 8) + key.suffix(4)
    }

    private var filteredHistory: [TranscriptRecord] {
        if searchText.isEmpty { return model.history }
        return model.history.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var visibleHistory: [TranscriptRecord] {
        Array(filteredHistory.prefix(displayLimit))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            contentArea
        }
        .frame(minWidth: 700, minHeight: 600)
        .background(Color.surfaceBase)
        .sheet(isPresented: $isRecordingShortcut) {
            ShortcutRecorderSheet(settings: model.settings, isPresented: $isRecordingShortcut)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Collapse toggle
            HStack {
                if !sidebarCollapsed {
                    Spacer()
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        sidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(sidebarCollapsed ? "Expand" : "Collapse")
                if sidebarCollapsed {
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            // App logo (waveform without rounded rect) — hidden when collapsed
            if !sidebarCollapsed {
                VStack(spacing: 5) {
                    Image("LogoWave")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 55)
                    Text("Blablabla")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        Text(v)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
                .padding(.bottom, 16)
            }

            // Gradient line
            Rectangle()
                .fill(brandGradient)
                .frame(height: 1)
                .padding(.horizontal, sidebarCollapsed ? 10 : 20)
                .opacity(0.4)

            // Tabs
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.horizontal, sidebarCollapsed ? 8 : 10)
            .padding(.top, 14)

            Spacer()

            // Status
            statusBar
        }
        .frame(width: sidebarCollapsed ? 54 : 200)
        .background(Color.surfaceSidebar)
    }

    @ViewBuilder
    private func sidebarButton(_ tab: SidebarTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.easeInOut(duration: 0.12)) { selectedTab = tab }
        } label: {
            Group {
                if sidebarCollapsed {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15))
                        .frame(width: 36, height: 34)
                        .help(tab.rawValue)
                } else {
                    HStack(spacing: 9) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                            .frame(width: 18)
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if tab == .transcripts && !model.history.isEmpty {
                            Text("\(model.history.count)")
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.white.opacity(0.12)))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? .white.opacity(0.08) : .clear)
            )
            .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
        }
        .buttonStyle(.plain)
    }

    private var statusBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                if !sidebarCollapsed {
                    Text(model.statusMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, sidebarCollapsed ? 0 : 14)
            .padding(.vertical, 10)
        }
    }

    private var statusColor: Color {
        switch model.sessionState {
        case .idle: .brandGreen
        case .listeningPushToTalk, .listeningLocked: .brandYellow
        case .finalizing: .brandCyan
        case .error: .brandPink
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .settings: settingsContent
                case .transcripts: transcriptsContent
                case .permissions: permissionsContent
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceBase)
    }

    // MARK: - Settings

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            // API Key
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AssemblyAI API Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    if settings.assemblyAIKey.isEmpty || isEditingAPIKey {
                        SecureField("Paste your AssemblyAI key", text: Binding(
                            get: { settings.assemblyAIKey },
                            set: { settings.assemblyAIKey = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.surfaceInput)
                        )

                        if isEditingAPIKey && !settings.assemblyAIKey.isEmpty {
                            HStack {
                                Spacer()
                                Button("Done") { isEditingAPIKey = false }
                                    .controlSize(.small)
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Text(maskedAPIKey)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.surfaceInput)
                            )

                            Button("Edit") { isEditingAPIKey = true }
                                .controlSize(.small)
                        }
                    }

                    Text("[Get a free API key at assemblyai.com](https://www.assemblyai.com/dashboard)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            // Usage
            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Usage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://www.assemblyai.com/app/usage")!)
                        } label: {
                            Text("View on AssemblyAI")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 20) {
                        usageStat("Sessions", value: "\(usageTracker.sessionCount)")
                        usageStat("Duration", value: usageTracker.formattedDuration)
                    }

                    HStack {
                        Text("Local tracking — check dashboard for exact usage")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                        Spacer()
                        Button("Reset") {
                            usageTracker.reset()
                        }
                        .font(.system(size: 11))
                        .controlSize(.small)
                    }
                }
            }

            // Shortcut
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shortcut")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    HStack(spacing: 12) {
                        keycapRow(settings.shortcutDescription)
                        Spacer()
                        Button("Record") { isRecordingShortcut = true }
                        Button("Reset") { settings.resetShortcutToDefault() }
                    }

                    Divider().opacity(0.3)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fn key push-to-talk")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Hold Fn alone to record")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.fnKeyEnabled },
                            set: { settings.fnKeyEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                }
            }

            // Microphone
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Microphone")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    HStack {
                        Picker("", selection: Binding(
                            get: { settings.selectedMicrophoneUID ?? "" },
                            set: { settings.selectedMicrophoneUID = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("System Default").tag("")
                            ForEach(availableDevices) { d in
                                Text(d.name).tag(d.uid)
                            }
                        }
                        .labelsHidden()
                        Button("Refresh") { refreshMicrophoneList() }
                    }
                }
            }
            .onAppear { refreshMicrophoneList() }

            // Sounds
            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sound Effects")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.soundEffectsEnabled },
                            set: { settings.soundEffectsEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }

                    if settings.soundEffectsEnabled {
                        Divider().opacity(0.3)

                        soundRow(
                            "Start recording",
                            selection: Binding(
                                get: { settings.startRecordingSound },
                                set: { settings.startRecordingSound = $0 }
                            )
                        )
                        soundRow(
                            "Locked recording",
                            selection: Binding(
                                get: { settings.lockedRecordingSound },
                                set: { settings.lockedRecordingSound = $0 }
                            )
                        )
                        soundRow(
                            "Stop recording",
                            selection: Binding(
                                get: { settings.stopRecordingSound },
                                set: { settings.stopRecordingSound = $0 }
                            )
                        )
                    }
                }
            }

            // Floating Panel
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Floating Panel Position")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow free positioning")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Drag the recording indicator anywhere on screen")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.floatingPanelFreePosition },
                            set: { settings.floatingPanelFreePosition = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }

                    if settings.floatingPanelFreePosition && settings.floatingPanelX != nil {
                        HStack {
                            Spacer()
                            Button("Reset to default") {
                                settings.resetFloatingPanelPosition()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

        }
    }

    private func soundRow(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Picker("", selection: selection) {
                ForEach(SoundEffectPlayer.availableSounds, id: \.self) { s in
                    Text(s).tag(s)
                }
            }
            .labelsHidden()
            .frame(width: 110)
            Button {
                SoundEffectPlayer().preview(selection.wrappedValue)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.surfaceInput)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Preview")
        }
    }

    // MARK: - Transcripts

    private var transcriptsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Transcripts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                if !filteredHistory.isEmpty {
                    Text("\(filteredHistory.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                if !model.history.isEmpty {
                    Button("Clear All", role: .destructive) { model.clearHistory() }
                        .controlSize(.small)
                }
            }

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.surfaceCard)
            )
            .onChange(of: searchText) { displayLimit = 10 }

            if filteredHistory.isEmpty {
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No transcripts yet" : "No results")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleHistory) { item in
                        transcriptRow(item)
                    }

                    if visibleHistory.count < filteredHistory.count {
                        Button {
                            displayLimit += 10
                        } label: {
                            Text("Show more (\(filteredHistory.count - visibleHistory.count))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func transcriptRow(_ item: TranscriptRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.insertedIntoFocusedApp ? "Pasted" : "History")
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(item.insertedIntoFocusedApp ? Color.brandGreen.opacity(0.8) : Color.brandYellow.opacity(0.8))
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.2))
            }

            Text(item.text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button {
                    model.copyTranscript(item.text)
                } label: {
                    Text("Copy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.surfaceCard)
        )
    }

    // MARK: - Permissions

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Permissions")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Refresh") { model.refreshPermissions() }
                    .controlSize(.small)
            }

            card {
                VStack(spacing: 0) {
                    // Microphone
                    HStack(spacing: 10) {
                        Circle()
                            .fill(model.permissionStatus.microphoneGranted ? Color.brandGreen : Color.brandYellow)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Microphone")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(microphoneDetail)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        if !model.permissionStatus.microphoneGranted {
                            if model.permissionStatus.microphoneStatus == .undetermined {
                                Button("Enable") { model.requestMicrophonePermission() }.controlSize(.small)
                            } else {
                                Button("Settings") { model.openMicrophoneSettings() }.controlSize(.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Divider().opacity(0.2).padding(.vertical, 4)

                    // Accessibility
                    HStack(spacing: 10) {
                        Circle()
                            .fill(model.permissionStatus.accessibilityGranted ? Color.brandGreen : Color.brandYellow)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Accessibility")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(model.permissionStatus.accessibilityGranted ? "Granted" : "Enable in System Settings")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        if !model.permissionStatus.accessibilityGranted {
                            Button("Enable") { model.requestAccessibilityPermission() }.controlSize(.small)
                            Button("Settings") { model.openAccessibilitySettings() }.controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider().opacity(0.2).padding(.vertical, 4)

                    // Input Monitoring
                    HStack(spacing: 10) {
                        Circle()
                            .fill(model.permissionStatus.inputMonitoringGranted ? Color.brandGreen : Color.brandYellow)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Input Monitoring")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(model.permissionStatus.inputMonitoringGranted ? "Granted" : "Enable in System Settings")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        if !model.permissionStatus.inputMonitoringGranted {
                            Button("Enable") { model.requestInputMonitoringPermission() }.controlSize(.small)
                            Button("Settings") { model.openInputMonitoringSettings() }.controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var microphoneDetail: String {
        switch model.permissionStatus.microphoneStatus {
        case .granted: "Granted"
        case .undetermined: "Click to allow"
        case .denied: "Denied — open Settings"
        }
    }

    // MARK: - Keycap helpers

    /// Map key names to SF Symbol / glyph equivalents
    private static let keySymbols: [String: String] = [
        "Command": "\u{2318}",
        "Control": "\u{2303}",
        "Option": "\u{2325}",
        "Shift": "\u{21E7}",
        "Fn": "fn",
        "Return": "\u{21A9}",
        "Tab": "\u{21E5}",
        "Delete": "\u{232B}",
        "Escape": "\u{238B}",
        "Space": "\u{2423}",
        "Left Arrow": "\u{2190}",
        "Right Arrow": "\u{2192}",
        "Up Arrow": "\u{2191}",
        "Down Arrow": "\u{2193}",
        "ISO Section": "\u{00A7}",
    ]

    private func keycapRow(_ description: String) -> some View {
        let keys = description
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                keycap(key)
            }
        }
    }

    private func keycap(_ key: String) -> some View {
        let display = Self.keySymbols[key] ?? key
        let isSymbol = Self.keySymbols[key] != nil && key != "Fn"

        return Text(display)
            .font(.system(
                size: isSymbol ? 14 : 11,
                weight: .medium,
                design: isSymbol ? .default : .rounded
            ))
            .foregroundStyle(.white.opacity(0.8))
            .frame(minWidth: 28, minHeight: 26)
            .padding(.horizontal, isSymbol ? 4 : 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.surfaceInput)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.08), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }

    private func usageStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Shared components

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.surfaceCard)
        )
    }
}
