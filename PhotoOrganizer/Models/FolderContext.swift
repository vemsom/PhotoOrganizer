import Foundation

/// Tolkning av den valda mappens namn.
/// Ex: "2024" → .year(2024); "2024-03" → .yearMonth(2024, 3); "2024-03-15" → .fullDate
struct FolderContext {
    enum Kind {
        /// Mappen har inget tolkbart datum. Full YYYY/MM/DD-struktur byggs.
        case none
        /// Mappen heter YYYY (4 siffror). Bygg endast MM/DD.
        case year(Int)
        /// Mappen heter YYYY-MM. Bygg endast DD.
        case yearMonth(year: Int, month: Int)
        /// Mappen heter YYYY-MM-DD. Bygg ändå YYYY/MM/DD under.
        case fullDate(year: Int, month: Int, day: Int)
    }

    let folderURL: URL
    let kind: Kind

    var humanDescription: String {
        switch kind {
        case .none:
            return "Ingen datumkontext (bygger YYYY/MM/DD)"
        case .year(let y):
            return "Tolkas som år \(y) (bygger MM/DD)"
        case .yearMonth(let y, let m):
            return String(format: "Tolkas som %04d-%02d (bygger DD)", y, m)
        case .fullDate(let y, let m, let d):
            return String(format: "Tolkas som fullt datum %04d-%02d-%02d (bygger ändå YYYY/MM/DD)", y, m, d)
        }
    }

    static func parse(folderURL: URL) -> FolderContext {
        let name = folderURL.lastPathComponent

        if let match = name.range(of: #"^(\d{4})-(\d{2})-(\d{2})$"#, options: .regularExpression) {
            let parts = String(name[match]).split(separator: "-").compactMap { Int($0) }
            if parts.count == 3, isValidDate(y: parts[0], m: parts[1], d: parts[2]) {
                return FolderContext(folderURL: folderURL, kind: .fullDate(year: parts[0], month: parts[1], day: parts[2]))
            }
        }
        if name.range(of: #"^(\d{4})-(\d{2})$"#, options: .regularExpression) != nil {
            let parts = name.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2, (1...12).contains(parts[1]) {
                return FolderContext(folderURL: folderURL, kind: .yearMonth(year: parts[0], month: parts[1]))
            }
        }
        if name.range(of: #"^\d{4}$"#, options: .regularExpression) != nil, let y = Int(name), (1900...2999).contains(y) {
            return FolderContext(folderURL: folderURL, kind: .year(y))
        }
        return FolderContext(folderURL: folderURL, kind: .none)
    }

    private static func isValidDate(y: Int, m: Int, d: Int) -> Bool {
        var components = DateComponents()
        components.year = y; components.month = m; components.day = d
        return Calendar(identifier: .gregorian).date(from: components) != nil && (1...12).contains(m) && (1...31).contains(d)
    }
}
