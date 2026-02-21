import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pipeline: ArticlePipeline
    @Query(sort: \Source.createdAt, order: .reverse) private var sources: [Source]

    @State private var showAddSheet = false
    @State private var newURL = ""
    @State private var newName = ""
    @State private var newType: SourceType = .channel
    @State private var importMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Source", systemImage: "plus")
                }

                Button {
                    importOPML()
                } label: {
                    Label("Import OPML", systemImage: "doc.badge.plus")
                }

                Spacer()

                if let msg = importMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            if sources.isEmpty {
                ContentUnavailableView(
                    "No Sources",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Add YouTube channels or playlists to auto-fetch new videos")
                )
            } else {
                List {
                    ForEach(sources) { source in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.name.isEmpty ? source.url : source.name)
                                    .font(.headline)
                                Text(source.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text(source.sourceType.rawValue.capitalized)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary)
                                        .clipShape(Capsule())
                                    Text("\(source.articles.count) articles")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            Toggle("Auto-fetch", isOn: Binding(
                                get: { source.autoFetch },
                                set: {
                                    source.autoFetch = $0
                                    do { try modelContext.save() } catch { print("Failed to save toggle: \(error)") }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()

                            Button {
                                fetchSource(source)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Fetch now")

                            Button(role: .destructive) {
                                modelContext.delete(source)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addSourceSheet
        }
    }

    // MARK: - Add source sheet

    private var addSourceSheet: some View {
        VStack(spacing: 16) {
            Text("Add Source")
                .font(.headline)

            TextField("YouTube URL", text: $newURL)
                .textFieldStyle(.roundedBorder)

            TextField("Name (optional)", text: $newName)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $newType) {
                ForEach(SourceType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }

            HStack {
                Button("Cancel") {
                    showAddSheet = false
                    newURL = ""
                    newName = ""
                }
                Spacer()
                Button("Add") {
                    addSource()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func addSource() {
        let url = newURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }

        let source = Source(url: url, sourceType: newType, name: newName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(source)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save source: \(error)")
        }

        newURL = ""
        newName = ""
        showAddSheet = false
    }

    private func fetchSource(_ source: Source) {
        Task {
            do {
                let urls: [String]
                switch source.sourceType {
                case .playlist:
                    urls = try await YTDLPService.shared.getPlaylistVideoURLs(url: source.url)
                case .channel:
                    if let info = try await YTDLPService.shared.getLatestFromChannel(handle: source.url) {
                        urls = [info.url]
                    } else {
                        urls = []
                    }
                case .video:
                    urls = [source.url]
                }

                for url in urls {
                    try pipeline.enqueue(url: url, modelContext: modelContext)
                }
            } catch {
                print("Source fetch failed: \(error)")
            }
        }
    }

    // MARK: - OPML Import

    private func importOPML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "opml") ?? .xml, .xml]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Could not read file"
                return
            }
            let count = OPMLImporter.importSources(from: data, into: modelContext)
            importMessage = "Imported \(count) sources"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                importMessage = nil
            }
        }
    }
}
