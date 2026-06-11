import SwiftUI

struct EmptyFolderCleanupView: View {
    let rootFolder: URL
    var onDone: () -> Void

    @State private var emptyFolders: [URL] = []
    @State private var isScanning = true
    @State private var isDeleting = false
    @State private var deletedCount: Int?
    @State private var failedCount = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let count = deletedCount {
                resultView(count: count)
            } else if isDeleting {
                VStack(spacing: 12) {
                    ProgressView("Rensar tomma mappar...")
                    Text("\(emptyFolders.count) mappar").foregroundStyle(.secondary)
                }
                .padding(40)
            } else if isScanning {
                VStack(spacing: 12) {
                    ProgressView("Söker efter tomma mappar...")
                }
                .padding(40)
                .task {
                    await scan()
                }
            } else if emptyFolders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("Inga tomma mappar hittades")
                        .font(.title3)
                }
                .padding(40)
                HStack {
                    Spacer()
                    Button("OK", action: onDone)
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                listView
            }
        }
        .padding()
        .frame(width: 560, height: 440)
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.badge.questionmark")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Hittade \(emptyFolders.count) tomma mapp\(emptyFolders.count == 1 ? "" : "ar")")
                    .font(.headline)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(emptyFolders, id: \.path) { url in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(relativePath(url))
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(6)
            }
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if let err = errorMessage {
                Text(err).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Button("Avbryt", action: onDone)
                Spacer()
                Button("Rensa \(emptyFolders.count) mapp\(emptyFolders.count == 1 ? "" : "ar")", role: .destructive) {
                    deleteFolders()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func resultView(count: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(failedCount == 0 ? .green : .orange)
            Text("Tog bort \(count) tomma mapp\(count == 1 ? "" : "ar")")
                .font(.title3)
            if failedCount > 0 {
                Text("Misslyckades med \(failedCount) mapp\(failedCount == 1 ? "" : "ar")")
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("OK", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
    }

    private func scan() async {
        let urls = await Task.detached {
            EmptyFolderRemover.scanEmptyDirectories(root: rootFolder)
        }.value
        await MainActor.run {
            emptyFolders = urls
            isScanning = false
        }
    }

    private func deleteFolders() {
        isDeleting = true
        let urls = emptyFolders
        Task {
            let (deleted, failed) = await Task.detached {
                EmptyFolderRemover.deleteDirectories(urls)
            }.value
            await MainActor.run {
                deletedCount = deleted
                failedCount = failed
                isDeleting = false
            }
        }
    }

    private func relativePath(_ url: URL) -> String {
        let root = rootFolder.path
        let full = url.path
        if full.hasPrefix(root) {
            return String(full.dropFirst(root.count + 1))
        }
        return full
    }
}
