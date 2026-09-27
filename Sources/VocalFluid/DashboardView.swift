import SwiftUI
import AppKit

public enum NavigationTab: String, CaseIterable, Identifiable {
    case dictation = "Dictation"
    case notetaker = "Notetaker"
    case insights = "Insights"
    case dictionary = "Dictionary"
    case snippets = "Snippets"
    case style = "Style"
    case transforms = "Transforms"
    case scratchpad = "Scratchpad"
    case settings = "Settings"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .dictation: return "mic"
        case .notetaker: return "record.circle"
        case .insights: return "chart.bar"
        case .dictionary: return "character.book.closed"
        case .snippets: return "scissors"
        case .style: return "textformat"
        case .transforms: return "wand.and.stars"
        case .scratchpad: return "note.text"
        case .settings: return "gear"
        }
    }
}

public struct DashboardView: View {
    @State private var selectedTab: NavigationTab = .dictation
    @ObservedObject var history = HistoryStore.shared
    @ObservedObject var styles = StyleManager.shared
    @StateObject private var settingsModel = SettingsModel()

    @State private var searchText: String = ""
    @State private var scratchpadText: String = ""
    @State private var isRecordingNote: Bool = false
    @State private var copiedId: UUID? = nil

    private var userName: String {
        let fullName = NSFullUserName()
        if !fullName.isEmpty {
            return fullName.components(separatedBy: " ").first ?? fullName
        }
        let user = NSUserName()
        return user.isEmpty ? "Joshua" : user.capitalized
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebarView
                .frame(width: 210)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

            Divider()

            // Main Content Area
            Group {
                switch selectedTab {
                case .dictation:
                    dictationMainView
                case .style:
                    styleView
                case .dictionary:
                    dictionaryView
                case .insights:
                    insightsView
                case .notetaker:
                    notetakerView
                case .snippets:
                    snippetsView
                case .transforms:
                    transformsView
                case .scratchpad:
                    scratchpadView
                case .settings:
                    SettingsView(model: settingsModel) {}
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    // MARK: - Sidebar View

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Logo Header
            HStack(spacing: 8) {
                // Waveform bars
                HStack(spacing: 2.5) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary).frame(width: 3, height: 12)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary).frame(width: 3, height: 18)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary).frame(width: 3, height: 14)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary).frame(width: 3, height: 20)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary).frame(width: 3, height: 10)
                }
                Text("VocalFluid")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Primary Navigation Items
            VStack(spacing: 2) {
                sidebarButton(tab: .dictation)
                sidebarButton(tab: .notetaker, badge: "New!")
                sidebarButton(tab: .insights)
                sidebarButton(tab: .dictionary)
                sidebarButton(tab: .snippets)
                sidebarButton(tab: .style)
                sidebarButton(tab: .transforms)
                sidebarButton(tab: .scratchpad)
            }
            .padding(.horizontal, 10)

            Spacer()

            // Local Engine Status Card
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("100% On-Device")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("WhisperKit (ANE) + Ollama\nZero cloud latency · 100% private")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            // Bottom Settings / Help
            VStack(spacing: 2) {
                sidebarButton(tab: .settings)
                Button(action: {
                    if let url = URL(string: "https://github.com/joshuajaimon7/FlowLocal") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 13))
                            .frame(width: 18)
                        Text("Help & Repo")
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)
        }
    }

    private func sidebarButton(tab: NavigationTab, badge: String? = nil) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                    .frame(width: 18)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.orange.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Dictation View (Matches Wispr Flow Screenshot)

    private var dictationMainView: some View {
        HStack(spacing: 0) {
            // Center Feed
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Greeting
                    HStack {
                        Text("Welcome back, \(userName)")
                            .font(.system(size: 26, weight: .bold))
                        Spacer()
                        Image(systemName: "bell")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color(nsColor: .controlColor)))

                        Circle()
                            .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(String(userName.prefix(1)))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }

                    // Hero Banner: "Make VocalFluid sound like you"
                    heroBannerCard

                    // History Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("RECENT DICTATIONS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                TextField("Search dictations…", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .frame(width: 140)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlColor).opacity(0.6))
                            .cornerRadius(6)
                        }

                        // Feed items
                        let filtered = history.records.filter {
                            searchText.isEmpty || $0.text.localizedCaseInsensitiveContains(searchText)
                        }

                        if filtered.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "waveform.and.mic")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.tertiary)
                                Text("No dictations yet")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Hold Fn (🌐) or Right ⌥ anywhere on your Mac to speak.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(filtered) { record in
                                    dictationFeedRow(record: record)
                                    Divider()
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                        }
                    }
                }
                .padding(26)
            }

            Divider()

            // Right Metrics Panel
            rightMetricsPanel
                .frame(width: 250)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
    }

    private var heroBannerCard: some View {
        ZStack(alignment: .leading) {
            // Dark elegant backdrop with gradient
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.14, green: 0.12, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Make VocalFluid sound like")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("you")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(Color.orange)
                    }

                    Text("Set up different writing styles for different apps.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.75))

                    Button(action: { selectedTab = .style }) {
                        Text("Configure Style")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white)
                            .cornerRadius(18)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(22)

                Spacer()

                // Subtle fluid wave graphic
                Image(systemName: "waveform")
                    .font(.system(size: 50, weight: .ultraLight))
                    .foregroundStyle(Color.white.opacity(0.15))
                    .padding(.trailing, 24)
            }
        }
        .frame(height: 140)
    }

    private func dictationFeedRow(record: DictationRecord) -> some View {
        HStack(alignment: .top, spacing: 18) {
            // Timestamp & App Badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeString(from: record.timestamp))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !record.appName.isEmpty {
                    Text(record.appName)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 65, alignment: .trailing)
            .padding(.top, 4)

            // Transcript Content
            VStack(alignment: .leading, spacing: 8) {
                Text(record.text)
                    .font(.system(size: 13.5))
                    .lineSpacing(3)
                    .foregroundStyle(.primary)

                // Actions bar
                HStack(spacing: 14) {
                    Button(action: { copyToClipboard(record.text, id: record.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedId == record.id ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copiedId == record.id ? "Copied" : "Copy")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(copiedId == record.id ? Color.green : Color.secondary)

                    Button(action: { history.toggleStar(id: record.id) }) {
                        Image(systemName: record.isStarred ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(record.isStarred ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.borderless)

                    Text("\(record.wordCount) words")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Button(action: { history.delete(id: record.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Right Metrics Panel

    private var rightMetricsPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Card 1: Dictation Stats
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(history.totalWords.formatted())")
                            .font(.system(size: 26, weight: .bold))
                        Text("total words")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(history.averageWPM)")
                            .font(.system(size: 26, weight: .bold))
                        Text("wpm")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(history.streakDays)")
                            .font(.system(size: 26, weight: .bold))
                        Text("day streak")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))

                // Card 2: 100% Local / Zero Cloud
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Local Unlimited")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        Spacer()
                        Image(systemName: "bolt.shield.fill")
                            .foregroundColor(.orange)
                    }
                    Text("Your voice and text never touch the cloud. Neural Engine acceleration provides infinite transcription without limits.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)

                    Button(action: { selectedTab = .settings }) {
                        Text("Engine Settings")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.orange.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))

                // Card 3: Voice Profile Active
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Voice Profile Active!")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                    }
                    Text("Active tone: \(styles.currentTone.rawValue)\nApp context awareness tuned for Slack, VS Code, and Mail.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)

                    Button(action: { selectedTab = .style }) {
                        Text("Tune Voice Profile")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
            }
            .padding(16)
        }
    }

    // MARK: - Style View (Phase 3 & 4)

    private var styleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Styles & Per-App Context")
                        .font(.system(size: 22, weight: .bold))
                    Text("Configure how VocalFluid cleans up your dictation. Adjust tone and provide sample writing so cleanup matches your personal voice.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                // Global Tone Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Tone")
                        .font(.system(size: 14, weight: .semibold))
                    Picker("Default Tone", selection: $styles.currentTone) {
                        ForEach(ToneMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(styles.currentTone.promptDirective)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)

                // My Style Reference
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("My Style Reference (Writing Samples)")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    Text("Paste 2–5 sentences of how you write (emails, messages, or notes). VocalFluid injects this into the Ollama cleanup pass to mirror your personal cadence.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $styles.myStyleReference)
                        .font(.system(size: 12.5, design: .monospaced))
                        .frame(height: 100)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)

                // Per-App Tone Mapping
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Per-App Tone Mapping")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button(action: {
                            styles.appToneRules.append(AppToneRule(appName: "New App", tone: .casual))
                        }) {
                            Label("Add App Rule", systemImage: "plus")
                                .font(.system(size: 12))
                        }
                    }
                    Text("Automatically apply custom tone based on the currently focused app.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    ForEach($styles.appToneRules) { $rule in
                        HStack {
                            TextField("App Name (e.g. Slack)", text: $rule.appName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)

                            Picker("Tone", selection: $rule.tone) {
                                ForEach(ToneMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .frame(width: 130)

                            Spacer()

                            Button(role: .destructive, action: {
                                styles.appToneRules.removeAll { $0.id == rule.id }
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding(26)
        }
    }

    // MARK: - Dictionary View (Phase 5)

    private var dictionaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Dictionary & Hotwords")
                        .font(.system(size: 22, weight: .bold))
                    Text("Biases WhisperKit recognition toward your technical terms, product names, and unique jargon. Optionally specify spelling corrections.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Custom Words & Acronyms")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button(action: {
                            settingsModel.vocabulary.append(VocabularyEntry(term: ""))
                        }) {
                            Label("Add Word", systemImage: "plus")
                                .font(.system(size: 12))
                        }
                    }

                    if settingsModel.vocabulary.isEmpty {
                        Text("No custom words added yet. Add proper nouns like 'VocalFluid', 'Kubernetes', or coworker names.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach($settingsModel.vocabulary) { $entry in
                            HStack {
                                TextField("Spoken Term (e.g. Wispr)", text: $entry.term)
                                    .textFieldStyle(.roundedBorder)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.tertiary)
                                TextField("Formatted (e.g. Wispr Flow)", text: $entry.replacement)
                                    .textFieldStyle(.roundedBorder)

                                Button(role: .destructive, action: {
                                    settingsModel.vocabulary.removeAll { $0.id == entry.id }
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding(26)
        }
    }

    // MARK: - Insights View (Phase 6)

    private var insightsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dictation Insights & Performance")
                        .font(.system(size: 22, weight: .bold))
                    Text("Real-time metrics on speaking speed, word totals, and latency.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    insightStatCard(title: "Words Dictated", value: "\(history.totalWords)", sub: "All time total", icon: "text.word.spacing")
                    insightStatCard(title: "Average Speed", value: "\(history.averageWPM) WPM", sub: "Speaking cadence", icon: "gauge.with.needle")
                    insightStatCard(title: "Daily Streak", value: "\(history.streakDays) Days", sub: "Consecutive use", icon: "flame.fill")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Local Architecture Performance")
                        .font(.system(size: 14, weight: .semibold))

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speech-to-Text Model")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(settingsModel.modelName)
                                .font(.system(size: 13, weight: .semibold))
                            Text("CoreML on Apple Neural Engine (ANE)")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        }

                        Divider().frame(height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cleanup LLM")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(settingsModel.ollamaModel)
                                .font(.system(size: 13, weight: .semibold))
                            Text("Local Ollama Server (\(settingsModel.ollamaEndpoint))")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(18)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding(26)
        }
    }

    private func insightStatCard(title: String, value: String, sub: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold))
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Notetaker View

    private var notetakerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continuous Notetaker")
                        .font(.system(size: 22, weight: .bold))
                    Text("Record meetings, brainstorms, or voice memos with live local transcription.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isRecordingNote.toggle() }) {
                    HStack(spacing: 6) {
                        Circle().fill(isRecordingNote ? Color.red : Color.green).frame(width: 8, height: 8)
                        Text(isRecordingNote ? "Stop Meeting Note" : "Start Live Note")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isRecordingNote ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: .constant(isRecordingNote ? "Listening continuously... (WhisperKit streaming)" : "Click 'Start Live Note' to transcribe continuously without holding down the hotkey."))
                .font(.system(size: 13))
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
        }
        .padding(26)
    }

    // MARK: - Scratchpad & Snippets & Transforms

    private var scratchpadView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voice Scratchpad")
                .font(.system(size: 22, weight: .bold))
            Text("A scratch space to dictate rough drafts, practice speech, or format text.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextEditor(text: $scratchpadText)
                .font(.system(size: 14))
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
        }
        .padding(26)
    }

    private var snippetsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Snippets & Expansion")
                .font(.system(size: 22, weight: .bold))
            Text("Spoken shorthand that instantly expands into pre-written paragraphs or templates.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Pre-configured Snippets:")
                    .font(.system(size: 13, weight: .semibold))
                Text("• 'my email' → your personal email\n• 'new line' → line break\n• 'new paragraph' → double line break\n• 'scratch that' → deletes previous dictation")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            Spacer()
        }
        .padding(26)
    }

    private var transformsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cleanup Transforms")
                .font(.system(size: 22, weight: .bold))
            Text("Rules that transform your raw spoken stream into clean, publication-ready text.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Picker("Intensity", selection: $settingsModel.intensity) {
                ForEach(CleanupIntensity.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text("Active Transformation Rules:")
                    .font(.system(size: 13, weight: .semibold))
                Text(settingsModel.intensity.promptRules)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            Spacer()
        }
        .padding(26)
    }

    // MARK: - Utilities

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).lowercased()
    }

    private func copyToClipboard(_ text: String, id: UUID) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copiedId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedId == id { copiedId = nil }
        }
    }
}
