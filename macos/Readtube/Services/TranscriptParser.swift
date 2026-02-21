import Foundation

/// Parses yt-dlp's JSON3 subtitle format into plain text.
enum TranscriptParser {
    /// Parse a JSON3 subtitle file into plain text transcript.
    /// JSON3 format: `{"events": [{"segs": [{"utf8": "text"}], "tStartMs": 0, "dDurationMs": 1000}, ...]}`
    static func parseJSON3(_ data: Data) throws -> String {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = obj["events"] as? [[String: Any]] else {
            throw TranscriptParserError.invalidFormat
        }

        var segments: [TranscriptSegment] = []

        for event in events {
            guard let segs = event["segs"] as? [[String: Any]] else { continue }
            let startMs = event["tStartMs"] as? Int ?? 0
            let durationMs = event["dDurationMs"] as? Int ?? 0

            var text = ""
            for seg in segs {
                if let utf8 = seg["utf8"] as? String {
                    text += utf8
                }
            }

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty || cleaned == "\n" { continue }

            segments.append(TranscriptSegment(
                text: cleaned,
                startSeconds: Double(startMs) / 1000.0,
                durationSeconds: Double(durationMs) / 1000.0
            ))
        }

        return joinSegments(segments)
    }

    /// Join segments into coherent text, merging duplicates and preserving speaker labels.
    private static func joinSegments(_ segments: [TranscriptSegment]) -> String {
        var result = ""
        var lastText = ""

        for segment in segments {
            let text = segment.text
            // Skip duplicate lines (common in auto-generated subs)
            if text == lastText { continue }

            // Detect speaker labels like "[Speaker]"
            if text.hasPrefix("[") && text.contains("]") {
                if let bracketEnd = text.firstIndex(of: "]") {
                    let speaker = String(text[text.index(after: text.startIndex)..<bracketEnd])
                    let rest = String(text[text.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)
                    if !result.isEmpty { result += "\n\n" }
                    result += "**\(speaker):** \(rest)"
                    lastText = text
                    continue
                }
            }

            if !result.isEmpty && !result.hasSuffix("\n") {
                result += " "
            }
            result += text
            lastText = text
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Format seconds as HH:MM:SS or MM:SS.
    static func formatTimestamp(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct TranscriptSegment {
    let text: String
    let startSeconds: Double
    let durationSeconds: Double
}

enum TranscriptParserError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid JSON3 subtitle format"
        }
    }
}
