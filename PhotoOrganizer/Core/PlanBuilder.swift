import Foundation

/// Bygger en plan (lista av PlannedOperation) från skannade filer – utan att skriva till disk.
struct PlanBuilder {
    let rootFolder: URL
    let context: FolderContext
    let files: [PhotoFile]

    struct Plan {
        var operations: [PlannedOperation]
        var rw2Count: Int
        var sortCount: Int
        var unsortedCount: Int
        var conflictCount: Int
    }

    func build(convertToDNG: Bool = true, sortFiles: Bool = true) -> Plan {
        var ops: [PlannedOperation] = []
        var rw2 = 0, sort = 0, unsorted = 0, conflict = 0

        let resolver = TargetPathResolver(rootFolder: rootFolder, context: context)

        // Fas 1: Samla RW2-filer som ska konverteras (endast om konvertering är på)
        // Efter konvertering kommer DNG:n sorteras i Fas 2 (vi lägger INTE in den sorten här;
        // OperationRunner skannar om efter konvertering).
        if convertToDNG {
            for f in files where f.kind == .rw2 {
                let dngURL = f.url.deletingPathExtension().appendingPathExtension("dng")
                ops.append(.convertRW2ToDNG(source: f.url, destinationDNG: dngURL, thenTrashSource: true))
                rw2 += 1
            }
        }

        // Fas 2: Sortera JPEG, DNG och RW2 som inte konverteras (endast om sortering är på)
        if sortFiles {
            for f in files where f.kind == .jpeg || f.kind == .dng || (f.kind == .rw2 && !convertToDNG) {
                guard let date = f.captureDate else {
                    let target = resolver.unsortedDirectory().appendingPathComponent(f.filename)
                    ops.append(.move(source: f.url, destination: target, reason: .unsortedNoDate))
                    unsorted += 1
                    continue
                }

                if resolver.hasConflict(for: date) {
                    let (ay, am) = resolver.folderAssertedYearMonth()
                    ops.append(.needsConflictDecision(source: f.url, exifDate: date, folderAssertedYear: ay, folderAssertedMonth: am))
                    conflict += 1
                    continue
                }

                let dir = resolver.targetDirectory(for: date)
                let target = dir.appendingPathComponent(f.filename)
                ops.append(.move(source: f.url, destination: target, reason: .sortedByDate(date: date)))
                sort += 1
            }
        }

        return Plan(operations: ops, rw2Count: rw2, sortCount: sort, unsortedCount: unsorted, conflictCount: conflict)
    }
}
