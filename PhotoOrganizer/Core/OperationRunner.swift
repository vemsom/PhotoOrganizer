import Foundation

/// Exekverar en plan mot disk. Conflict-beslut levereras in via dictionary (keyed by source URL).
@MainActor
final class OperationRunner: ObservableObject {
    @Published var currentPhase: String = ""
    @Published var progressValue: Double = 0
    @Published var progressTotal: Double = 1
    @Published var isRunning: Bool = false
    @Published var isCancelled: Bool = false

    unowned let log: OperationLog
    init(log: OperationLog) { self.log = log }

    struct RunResult {
        var convertedRW2: Int = 0
        var trashedRW2: Int = 0
        var movedJPEG: Int = 0
        var movedDNG: Int = 0
        var movedRW2: Int = 0
        var movedToUnsorted: Int = 0
        var skipped: Int = 0
        var removedEmptyFolders: Int = 0
        var errors: Int = 0
    }

    func cancel() { isCancelled = true }

    func run(
        plan: PlanBuilder.Plan,
        rootFolder: URL,
        context: FolderContext,
        conflictDecisions: [URL: ConflictDecision],
        convertToDNG: Bool = true,
        sortFiles: Bool = true,
        deleteEmptyFolders: Bool = false
    ) async -> RunResult {
        isRunning = true
        isCancelled = false
        defer { isRunning = false }

        var result = RunResult()

        // --- Fas 1: Konvertera RW2 → DNG ---
        let convertOps = plan.operations.compactMap { op -> (URL, URL)? in
            if case .convertRW2ToDNG(let s, let d, _) = op { return (s, d) }
            return nil
        }

        if convertToDNG && !convertOps.isEmpty {
            currentPhase = sortFiles ? "Fas 1 av 2: Konverterar RW2 → DNG" : "Konverterar RW2 → DNG"
            await Task.yield()
        }
        progressTotal = Double(max(convertOps.count, 1))
        progressValue = 0

        var convertedDNGs: [URL] = []

        for (source, _) in convertOps {
            if isCancelled { log.log(.warn, "Avbruten av användare"); return result }

            log.log(.info, "Konverterar \(source.lastPathComponent)")
            do {
                let dngURL = try await Task.detached(priority: .userInitiated) {
                    try DNGConverter().convert(source: source)
                }.value

                convertedDNGs.append(dngURL)
                result.convertedRW2 += 1
                log.log(.success, "DNG skapad: \(dngURL.lastPathComponent)")

                // Släng RW2 + eventuella sidecar-filer
                do {
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: source, resultingItemURL: &resulting)
                    result.trashedRW2 += 1
                    log.log(.info, "Flyttade RW2 till papperskorgen: \(source.lastPathComponent)")
                } catch {
                    result.errors += 1
                    log.log(.error, "Kunde inte flytta RW2 till papperskorg (\(source.lastPathComponent)): \(error.localizedDescription)")
                }

                trashSidecars(for: source)
            } catch {
                result.errors += 1
                log.log(.error, "Konvertering misslyckades för \(source.lastPathComponent): \(error.localizedDescription)")
            }
            progressValue += 1
            await Task.yield()
        }

        // --- Fas 2: Sortera JPEG/DNG/RW2 ---
        if sortFiles {
            currentPhase = convertToDNG ? "Fas 2 av 2: Sorterar filer i datum-mappar" : "Sorterar filer i datum-mappar"
            await Task.yield()
        }

        var moves: [(source: URL, destination: URL, reason: PlannedOperation.MoveReason)] = []

        for op in plan.operations {
            switch op {
            case .move(let s, let d, let r):
                moves.append((s, d, r))
            case .needsConflictDecision(let s, let exifDate, _, _):
                let decision = conflictDecisions[s] ?? .moveToUnsorted
                let resolver = TargetPathResolver(rootFolder: rootFolder, context: context)
                switch decision {
                case .keepExifDate:
                    let fallbackResolver = TargetPathResolver(
                        rootFolder: rootFolder,
                        context: FolderContext(folderURL: rootFolder, kind: .none)
                    )
                    let dir = fallbackResolver.targetDirectory(for: exifDate)
                    moves.append((s, dir.appendingPathComponent(s.lastPathComponent), .sortedByDate(date: exifDate)))
                case .moveToUnsorted:
                    let dir = resolver.unsortedDirectory()
                    moves.append((s, dir.appendingPathComponent(s.lastPathComponent), .unsortedUserChoice))
                case .skip:
                    result.skipped += 1
                    log.log(.info, "Hoppade över (användarval): \(s.lastPathComponent)")
                }
            default: break
            }
        }

        // Lägg till nya DNG:er som skapats i Fas 1 (endast om sortering är på)
        if sortFiles {
            for dngURL in convertedDNGs {
                let (date, _) = ExifReader.readCaptureDate(url: dngURL)
                let resolver = TargetPathResolver(rootFolder: rootFolder, context: context)
                if let date, !resolver.hasConflict(for: date) {
                    let dir = resolver.targetDirectory(for: date)
                    moves.append((dngURL, dir.appendingPathComponent(dngURL.lastPathComponent), .sortedByDate(date: date)))
                } else if date != nil {
                    let dir = resolver.unsortedDirectory()
                    moves.append((dngURL, dir.appendingPathComponent(dngURL.lastPathComponent), .unsortedUserChoice))
                    log.log(.warn, "Konverterad DNG \(dngURL.lastPathComponent) hamnar i _unsorted/ pga datum-mismatch mot mappnamn")
                } else {
                    let dir = resolver.unsortedDirectory()
                    moves.append((dngURL, dir.appendingPathComponent(dngURL.lastPathComponent), .unsortedNoDate))
                }
            }
        }

        progressTotal = Double(max(moves.count, 1))
        progressValue = 0

        var movedSources: [URL] = []

        for m in moves {
            if isCancelled { log.log(.warn, "Avbruten av användare"); return result }

            let destDir = m.destination.deletingLastPathComponent()
            let sidecars = Self.findSidecars(for: m.source)

            do {
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.createDirectory(
                        at: destDir,
                        withIntermediateDirectories: true
                    )
                    let finalDest = TargetPathResolver.resolveConflict(at: m.destination)
                    try FileManager.default.moveItem(at: m.source, to: finalDest)

                    // Hantera sidecar-filer för källfilen
                    for sidecar in sidecars {
                        let sidecarDest = destDir.appendingPathComponent(sidecar.lastPathComponent)
                        let finalSidecar = TargetPathResolver.resolveConflict(at: sidecarDest)
                        try FileManager.default.moveItem(at: sidecar, to: finalSidecar)
                    }
                }.value

                let ext = m.source.pathExtension.lowercased()
                if ext == "dng" { result.movedDNG += 1 }
                else if ext == "jpg" || ext == "jpeg" { result.movedJPEG += 1 }
                else if ext == "rw2" { result.movedRW2 += 1 }

                switch m.reason {
                case .unsortedNoDate, .unsortedUserChoice:
                    result.movedToUnsorted += 1
                case .sortedByDate: break
                }

                movedSources.append(m.source)
                log.log(.success, "Flyttade \(m.source.lastPathComponent) → \(destDir.path)")
            } catch {
                result.errors += 1
                log.log(.error, "Kunde inte flytta \(m.source.lastPathComponent): \(error.localizedDescription)")
            }
            progressValue += 1
            await Task.yield()
        }

        // Rensa tomma kataloger (efter flytt)
        if !movedSources.isEmpty {
            currentPhase = "Rensar tomma mappar..."
            await Task.yield()
            cleanUpEmptyDirectories(root: rootFolder, movedSources: movedSources)
        }

        // Rensa alla tomma kataloger (wide scan, om aktiverat)
        if deleteEmptyFolders {
            currentPhase = "Rensar alla tomma mappar..."
            await Task.yield()
            let empty = EmptyFolderRemover.scanEmptyDirectories(root: rootFolder)
            if !empty.isEmpty {
                let (deleted, _) = EmptyFolderRemover.deleteDirectories(empty, root: rootFolder) { msg in
                    let level: OperationLog.Level = msg.hasPrefix("Kunde") ? .warn : .info
                    self.log.log(level, msg)
                }
                result.removedEmptyFolders = deleted
            } else {
                log.log(.info, "Inga tomma mappar hittades.")
            }
        }

        currentPhase = "Klar"
        return result
    }

    // MARK: - Sidecar-hantering

    private nonisolated static func findSidecars(for url: URL) -> [URL] {
        let extensions = ["pp3", "rrdata"]
        return extensions.compactMap { ext in
            let sidecar = url.appendingPathExtension(ext)
            return FileManager.default.fileExists(atPath: sidecar.path) ? sidecar : nil
        }
    }

    private func trashSidecars(for url: URL) {
        for sidecar in Self.findSidecars(for: url) {
            do {
                try FileManager.default.trashItem(at: sidecar, resultingItemURL: nil)
                log.log(.info, "Slängde sidecar: \(sidecar.lastPathComponent)")
            } catch {
                log.log(.warn, "Kunde inte slänga sidecar \(sidecar.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Rensa tomma mappar

    private func cleanUpEmptyDirectories(root: URL, movedSources: [URL]) {
        let fm = FileManager.default
        var processed = Set<URL>()

        for source in movedSources {
            var dir = source.deletingLastPathComponent()

            while dir != root && !processed.contains(dir) {
                processed.insert(dir)

                let contents = (try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )) ?? []

                if contents.isEmpty {
                    do {
                        try fm.removeItem(at: dir)
                        log.log(.info, "Tog bort tom mapp: \(dir.lastPathComponent)")
                    } catch {
                        log.log(.warn, "Kunde inte ta bort tom mapp \(dir.lastPathComponent): \(error.localizedDescription)")
                        break
                    }
                } else {
                    break
                }

                dir = dir.deletingLastPathComponent()
            }
        }
    }
}
