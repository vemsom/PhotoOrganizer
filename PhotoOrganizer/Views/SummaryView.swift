import SwiftUI
import AppKit

struct SummaryView: View {
    let result: OperationRunner.RunResult
    let rootFolder: URL?
    @ObservedObject var log: OperationLog
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: result.errors == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(result.errors == 0 ? .green : .orange)
                Text(result.errors == 0 ? "Klart!" : "Klart med varningar")
                    .font(.title).bold()
            }

            GroupBox("Sammanfattning") {
                VStack(alignment: .leading, spacing: 6) {
                    row("Konverterade RW2 → DNG", result.convertedRW2)
                    row("RW2 flyttade till papperskorgen", result.trashedRW2)
                    row("Flyttade JPEG", result.movedJPEG)
                    row("Flyttade DNG", result.movedDNG)
                    row("Flyttade RW2", result.movedRW2)
                    row("Hamnade i _unsorted/", result.movedToUnsorted)
                    row("Hoppade över", result.skipped)
                    if result.removedEmptyFolders > 0 {
                        row("Tog bort tomma mappar", result.removedEmptyFolders)
                    }
                    row("Fel", result.errors, highlight: result.errors > 0)
                }
                .padding(8)
            }

            GroupBox("Logg") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(log.entries) { e in
                            HStack(alignment: .top) {
                                Text(icon(for: e.level))
                                Text(e.message).font(.callout)
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 260)
            }

            HStack {
                if let url = rootFolder {
                    Button("Öppna i Finder") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Kopiera logg") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(log.exportAsText(), forType: .string)
                }
                Spacer()
                Button("Börja om", action: onReset)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func row(_ label: String, _ n: Int, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(n)").bold().foregroundStyle(highlight ? .red : .primary)
        }
    }

    private func icon(for level: OperationLog.Level) -> String {
        switch level {
        case .info: return "ℹ︎"
        case .warn: return "⚠︎"
        case .error: return "✖︎"
        case .success: return "✓"
        }
    }
}
