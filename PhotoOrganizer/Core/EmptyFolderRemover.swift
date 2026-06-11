import Foundation

struct EmptyFolderRemover {
    static func scanEmptyDirectories(root: URL, includeHidden: Bool = false) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsPackageDescendants
        ) else { return [] }

        var candidates: [URL] = []

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }

            if !includeHidden {
                let name = url.lastPathComponent
                if name.hasPrefix(".") { continue }
            }

            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            if contents.isEmpty {
                candidates.append(url)
            }
        }

        return candidates.sorted { $0.path.count > $1.path.count }
    }

    static func deleteDirectories(_ directories: [URL], root: URL? = nil, log: ((String) -> Void)? = nil) -> (deleted: Int, failed: Int) {
        let fm = FileManager.default
        var deleted = 0
        var failed = 0
        var toProcess = directories

        while !toProcess.isEmpty {
            let url = toProcess.removeFirst()
            guard fm.fileExists(atPath: url.path) else { continue }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }

            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            guard contents.isEmpty else { continue }

            do {
                try fm.removeItem(at: url)
                deleted += 1
                log?("Tog bort tom mapp: \(url.path)")

                if let root, url != root {
                    toProcess.append(url.deletingLastPathComponent())
                }
            } catch {
                failed += 1
                log?("Kunde inte ta bort \(url.path): \(error.localizedDescription)")
            }
        }

        return (deleted, failed)
    }
}
