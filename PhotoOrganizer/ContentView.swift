import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedFolder: URL?
    @State private var folderContext: FolderContext?
    @State private var scannedFiles: [PhotoFile] = []
    @State private var plan: PlanBuilder.Plan?
    @State private var conflictDecisions: [URL: ConflictDecision] = [:]
    @State private var showSummary = false
    @State private var runResult: OperationRunner.RunResult?
    @State private var scanError: String?
    @State private var convertToDNG = true
    @State private var sortFiles = true
    @State private var recurseSubfolders = false
    @State private var isScanning = false
    @State private var scanningFile: String?

    @StateObject private var log = OperationLog()
    @StateObject private var runner: OperationRunner

    init() {
        let l = OperationLog()
        _log = StateObject(wrappedValue: l)
        _runner = StateObject(wrappedValue: OperationRunner(log: l))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                header

                if runner.isRunning {
                    ProgressOverlayView(runner: runner)
                } else if showSummary, let runResult {
                    SummaryView(
                        result: runResult,
                        rootFolder: selectedFolder,
                        log: log,
                        onReset: resetAll
                    )
                } else if let plan {
                    PlanPreviewView(
                        plan: plan,
                        folderContext: folderContext,
                        rootFolder: selectedFolder,
                        conflictDecisions: $conflictDecisions,
                        onCancel: resetAll,
                        onRun: { Task { await executePlan() } }
                    )
                } else {
                    FolderPickerView(
                        selectedFolder: $selectedFolder,
                        scanError: $scanError,
                        convertToDNG: $convertToDNG,
                        sortFiles: $sortFiles,
                        recurseSubfolders: $recurseSubfolders,
                        onPick: pickFolder,
                        onScan: scanAndPlan
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            .opacity(isScanning ? 0.3 : 1)
            .disabled(isScanning)

            if isScanning {
                ScanningOverlay(fileName: $scanningFile)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PhotoOrganizer")
                .font(.largeTitle).bold()
            Spacer()
            if let url = selectedFolder {
                Text(url.path).font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
        }
    }

    // MARK: - Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Välj fotomapp"
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            scannedFiles = []
            plan = nil
            scanError = nil
            runResult = nil
            showSummary = false
            conflictDecisions = [:]
            folderContext = FolderContext.parse(folderURL: url)
            isScanning = false
            scanningFile = nil
        }
    }

    private func scanAndPlan() {
        guard let folder = selectedFolder else { return }
        scanError = nil
        isScanning = true
        scanningFile = "Startar..."
        let recursive = recurseSubfolders

        Task {
            let files: [PhotoFile]
            do {
                files = try await Task.detached(priority: .userInitiated) {
                    try PhotoScanner().scan(folder: folder, recursive: recursive) { url in
                        Task { @MainActor in
                            scanningFile = url.lastPathComponent
                        }
                    }
                }.value
            } catch {
                await MainActor.run {
                    scanError = error.localizedDescription
                    isScanning = false
                    scanningFile = nil
                }
                return
            }

            await MainActor.run {
                scannedFiles = files
                let ctx = folderContext ?? FolderContext.parse(folderURL: folder)
                folderContext = ctx
                plan = PlanBuilder(rootFolder: folder, context: ctx, files: files).build(
                    convertToDNG: convertToDNG,
                    sortFiles: sortFiles
                )
                log.log(.info, "Skannade \(files.count) filer i \(folder.lastPathComponent)")
                log.log(.info, ctx.humanDescription)
                isScanning = false
                scanningFile = nil
            }
        }
    }

    private func executePlan() async {
        guard let plan, let folder = selectedFolder, let ctx = folderContext else { return }
        let result = await runner.run(
            plan: plan,
            rootFolder: folder,
            context: ctx,
            conflictDecisions: conflictDecisions,
            convertToDNG: convertToDNG,
            sortFiles: sortFiles
        )
        runResult = result
        showSummary = true
    }

    private func resetAll() {
        selectedFolder = nil
        folderContext = nil
        scannedFiles = []
        plan = nil
        conflictDecisions = [:]
        runResult = nil
        showSummary = false
        scanError = nil
        isScanning = false
        scanningFile = nil
        log.clear()
    }
}
