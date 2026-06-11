import Foundation

struct EmptyFolderRemover {
    static func scanEmptyDirectories(root: URL, includeHidden: Bool = false) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants]
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

        return candidates.sorted { $0.path > $1.path }
    }

    static func deleteDirectories(_ directories: [URL], log: ((String) -> Void)? = nil) -> (deleted: Int, failed: Int) {
        var deleted = 0
        var failed = 0

        for url in directories {
            do {
                try FileManager.default.removeItem(at: url)
                deleted += 1
                log?("Tog bort tom mapp: \(url.path)")
            } catch {
                failed += 1
                log?("Kunde inte ta bort \(url.path): \(error.localizedDescription)")
            }
        }

        return (deleted, failed)
    }
}
