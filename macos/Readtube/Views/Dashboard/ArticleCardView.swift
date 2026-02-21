import SwiftUI

struct ArticleCardView: View {
    let article: Article

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbURL = article.thumbnailURL, let url = URL(string: thumbURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.secondary)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title.isEmpty ? article.videoID : article.title)
                    .font(.headline)
                    .lineLimit(2)

                if !article.channel.isEmpty {
                    Text(article.channel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    statusBadge
                    if article.duration > 0 {
                        Text(formatDuration(article.duration))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(article.status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch article.status {
        case .pending: return .gray
        case .fetching: return .blue
        case .transcribing: return .cyan
        case .generating: return .orange
        case .done: return .green
        case .error: return .red
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
