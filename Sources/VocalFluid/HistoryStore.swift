import Foundation

public struct DictationRecord: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var text: String
    public var rawText: String
    public var appName: String
    public var durationSeconds: Double
    public var wordCount: Int
    public var isStarred: Bool = false

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        rawText: String,
        appName: String,
        durationSeconds: Double,
        wordCount: Int,
        isStarred: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.rawText = rawText
        self.appName = appName
        self.durationSeconds = durationSeconds
        self.wordCount = wordCount
        self.isStarred = isStarred
    }
}

@MainActor
public final class HistoryStore: ObservableObject {
    public static let shared = HistoryStore()

    @Published public var records: [DictationRecord] = []
    @Published public var totalWords: Int = 0
    @Published public var averageWPM: Int = 145
    @Published public var streakDays: Int = 1

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VocalFluid", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.fileURL = appSupport.appendingPathComponent("records.json")

        load()
        if records.isEmpty {
            seedSampleHistory()
        }
        recalculateStats()
    }

    public func add(text: String, rawText: String, appName: String, duration: Double) {
        let words = text.split { $0.isWhitespace }.count
        let record = DictationRecord(
            text: text,
            rawText: rawText,
            appName: appName,
            durationSeconds: max(0.5, duration),
            wordCount: words
        )
        records.insert(record, at: 0)
        recalculateStats()
        save()
    }

    public func delete(id: UUID) {
        records.removeAll { $0.id == id }
        recalculateStats()
        save()
    }

    public func toggleStar(id: UUID) {
        if let idx = records.firstIndex(where: { $0.id == id }) {
            records[idx].isStarred.toggle()
            save()
        }
    }

    public func clearAll() {
        records.removeAll()
        recalculateStats()
        save()
    }

    private func recalculateStats() {
        totalWords = records.reduce(0) { $0 + $1.wordCount }

        let validWPMSamples = records.filter { $0.durationSeconds >= 1.0 && $0.wordCount >= 3 }
        if !validWPMSamples.isEmpty {
            let totalSeconds = validWPMSamples.reduce(0.0) { $0 + $1.durationSeconds }
            let totalWordsInSamples = validWPMSamples.reduce(0) { $0 + $1.wordCount }
            if totalSeconds > 0 {
                averageWPM = max(80, Int((Double(totalWordsInSamples) / totalSeconds) * 60.0))
            }
        } else {
            averageWPM = 148
        }

        // Calculate active streak days
        let calendar = Calendar.current
        var uniqueDays = Set<DateComponents>()
        for record in records {
            let comps = calendar.dateComponents([.year, .month, .day], from: record.timestamp)
            uniqueDays.insert(comps)
        }
        streakDays = max(1, uniqueDays.count)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            flog("[history] Failed to save records: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([DictationRecord].self, from: data)
        } catch {
            flog("[history] Failed to load records: \(error)")
        }
    }

    private func seedSampleHistory() {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now

        let samples: [DictationRecord] = [
            DictationRecord(
                timestamp: calendar.date(bySettingHour: 17, minute: 5, second: 0, of: yesterday) ?? yesterday,
                text: "I saw that the dashboard is full of colours and stuff. It has rounded edges and many things so I want you to make it sharp and professional in style. We don't need many colours and we only need colours on, at most, danger things. We don't need green, yellow, red, and all. Just need to make sure it works. Make it very professional and minimal. Users should understand what it is at first glance properly. Can you do it?",
                rawText: "i saw that the dashboard is full of colours and stuff it has rounded edges and many things so i want you to make it sharp and professional in style we don't need many colours and we only need colours on at most danger things we don't need green yellow red and all just need to make sure it works make it very professional and minimal users should understand what it is at first glance properly can you do it",
                appName: "Notes",
                durationSeconds: 16.5,
                wordCount: 78
            ),
            DictationRecord(
                timestamp: calendar.date(bySettingHour: 16, minute: 52, second: 0, of: yesterday) ?? yesterday,
                text: "Next is API keys. Of course we need API keys because the install command includes API keys so we need to keep that.",
                rawText: "next is api keys of course we need api keys because the install command includes api keys so we need to keep that",
                appName: "Slack",
                durationSeconds: 5.2,
                wordCount: 22
            ),
            DictationRecord(
                timestamp: calendar.date(bySettingHour: 16, minute: 48, second: 0, of: yesterday) ?? yesterday,
                text: "Settings: need smart policy. I don't know how it works in the policy section. Make sure the policy section works end to end. The policy section is where we set file blocking, etc.\n\nI don't know what rules are and what models are. I want you to scan it again and I want to check the architecture to check which is supported and which is not supported so we can actually remove things we don't need.",
                rawText: "settings need smart policy i don't know how it works in the policy section make sure the policy section works end to end the policy section is where we set file blocking etc new paragraph i don't know what rules are and what models are i want you to scan it again and i want to check the architecture to check which is supported and which is not supported so we can actually remove things we don't need",
                appName: "VS Code",
                durationSeconds: 18.0,
                wordCount: 74
            )
        ]

        records = samples
        save()
    }
}
