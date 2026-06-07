import Foundation

/// Bygger mål-URL för en fil baserat på EXIF-datum och den valda mappens kontext.
struct TargetPathResolver {
    let rootFolder: URL
    let context: FolderContext

    /// Bygger mål-mapp (utan filnamn) för ett givet datum.
    func targetDirectory(for date: Date) -> URL {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        let yyyy = String(format: "%04d", y)
        let mm = String(format: "%02d", m)
        let dd = String(format: "%02d", d)

        switch context.kind {
        case .none:
            return rootFolder.appendingPathComponent(yyyy).appendingPathComponent(mm).appendingPathComponent(dd)
        case .year:
            // Vi vet redan YYYY från mappnamnet, bygg MM/DD
            return rootFolder.appendingPathComponent(mm).appendingPathComponent(dd)
        case .yearMonth:
            // Vi vet YYYY och MM, bygg bara DD
            return rootFolder.appendingPathComponent(dd)
        case .fullDate:
            // Användaren valde: "Skapa ändå YYYY/MM/DD under"
            return rootFolder.appendingPathComponent(yyyy).appendingPathComponent(mm).appendingPathComponent(dd)
        }
    }

    func unsortedDirectory() -> URL {
        rootFolder.appendingPathComponent("_unsorted", isDirectory: true)
    }

    /// Om mappkontexten hävdar ett år/månad som motsäger EXIF-datumet.
    func hasConflict(for date: Date) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        switch context.kind {
        case .none:
            return false
        case .year(let y):
            return comps.year != y
        case .yearMonth(let y, let m):
            return comps.year != y || comps.month != m
        case .fullDate(let y, let m, let d):
            return comps.year != y || comps.month != m || comps.day != d
        }
    }

    func folderAssertedYearMonth() -> (Int?, Int?) {
        switch context.kind {
        case .none: return (nil, nil)
        case .year(let y): return (y, nil)
        case .yearMonth(let y, let m): return (y, m)
        case .fullDate(let y, let m, _): return (y, m)
        }
    }

    /// Lägger till suffix -1, -2, ... om målfilen redan finns.
    static func resolveConflict(at url: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { return url }

        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent

        var i = 1
        while true {
            let candidateName = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
            let candidate = dir.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
            if i > 9999 { return candidate }
        }
    }
}
