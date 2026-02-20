import Foundation

public struct ShareDraftOptions: Sendable, Equatable {
    public var instruction: String?
    public var imageAttachmentCount: Int
    public var maxCharacters: Int

    public init(instruction: String? = nil, imageAttachmentCount: Int = 0, maxCharacters: Int = 2400) {
        self.instruction = instruction
        self.imageAttachmentCount = imageAttachmentCount
        self.maxCharacters = maxCharacters
    }
}

public enum ShareDraftBuilder {
    private static let minMaxCharacters = 240
    private static let bannedLinePrefixes = [
        "shared from ios.",
        "text:",
        "shared attachment(s):",
        "please help me with this.",
        "please help me with this.w",
    ]

    public static func build(
        from payload: SharedContentPayload,
        options: ShareDraftOptions = ShareDraftOptions()) -> String
    {
        let title = self.clean(payload.title)
        let urlText = self.clean(payload.url?.absoluteString)
        let instruction = self.clean(options.instruction) ?? ShareToAgentSettings.loadDefaultInstruction()
        let normalizedText = self.normalizeSharedText(payload.text, duplicateURLText: urlText)
        let imageAttachmentCount = max(0, options.imageAttachmentCount)

        var lines = ["Shared from iOS."]
        if let title {
            lines.append("Title: \(title)")
        }
        if let urlText {
            lines.append("URL: \(urlText)")
        }
        if let normalizedText {
            lines.append("Text:\n\(normalizedText)")
        }
        if imageAttachmentCount > 0 {
            lines.append("Attached image(s): \(imageAttachmentCount)")
        }
        lines.append(instruction)

        let maxCharacters = max(self.minMaxCharacters, options.maxCharacters)
        return self.limit(lines.joined(separator: "\n\n"), maxCharacters: maxCharacters)
    }

    private static func normalizeSharedText(_ raw: String?, duplicateURLText: String?) -> String? {
        guard let raw = self.clean(raw) else { return nil }

        let loweredURL = duplicateURLText?.lowercased()
        let sanitizedLines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty else { return false }
                let lowered = line.lowercased()
                guard !self.bannedLinePrefixes.contains(where: { lowered == $0 || lowered.hasPrefix($0) }) else {
                    return false
                }
                guard let loweredURL else { return true }
                if lowered == loweredURL { return false }
                if lowered == "url: \(loweredURL)" { return false }
                return true
            }

        let normalized = sanitizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func limit(_ value: String, maxCharacters: Int) -> String {
        guard value.count > maxCharacters else { return value }
        return String(value.prefix(maxCharacters))
    }
}
