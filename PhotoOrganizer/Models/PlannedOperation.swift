import Foundation

/// Ett steg i den planerade körningen. Inget skrivs till disk förrän användaren godkänner.
enum PlannedOperation: Identifiable {
    case convertRW2ToDNG(source: URL, destinationDNG: URL, thenTrashSource: Bool)
    case move(source: URL, destination: URL, reason: MoveReason)
    case skip(source: URL, reason: String)
    case needsConflictDecision(source: URL, exifDate: Date, folderAssertedYear: Int?, folderAssertedMonth: Int?)

    enum MoveReason {
        case sortedByDate(date: Date)
        case unsortedNoDate
        case unsortedUserChoice
    }

    var id: String {
        switch self {
        case .convertRW2ToDNG(let s, _, _): return "conv:\(s.path)"
        case .move(let s, _, _): return "move:\(s.path)"
        case .skip(let s, _): return "skip:\(s.path)"
        case .needsConflictDecision(let s, _, _, _): return "conflict:\(s.path)"
        }
    }

    var sourceURL: URL {
        switch self {
        case .convertRW2ToDNG(let s, _, _): return s
        case .move(let s, _, _): return s
        case .skip(let s, _): return s
        case .needsConflictDecision(let s, _, _, _): return s
        }
    }
}

/// Användarens beslut vid datum-mismatch.
enum ConflictDecision {
    case keepExifDate        // Använd EXIF-datumet, placera i rätt datummapp oavsett vald mapp
    case moveToUnsorted      // Till _unsorted/
    case skip                // Hoppa över filen helt
}
