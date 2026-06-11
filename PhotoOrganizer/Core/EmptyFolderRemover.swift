import Foundation

struct EmptyFolderRemover {
    static func scanEmptyDirectories(root: URL, includeHidden: Bool = false) -> [URL] {
        var candidates: [URL] = []
        scanRecursive(fm: FileManager.default, dir: root, isRoot: true, includeHidden: includeHidden, candidates: &candidates)
        return candidates.sorted { $0.path.count > $1.path.count }
    }

    private static func scanRecursive(fm: FileManager, dir: URL, isRoot: Bool, includeHidden: Bool, candidates: inout [URL]) {
        let opts: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        let contents = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: opts)) ?? []

        var subdirs: [URL] = []
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let name = url.lastPathComponent
            if includeHidden || !name.hasPrefix(".") {
                subdirs.append(url)
            }
        }

        for subdir in subdirs {
            scanRecursive(fm: fm, dir: subdir, isRoot: false, includeHidden: includeHidden, candidates: &candidates)
        }

        if contents.isEmpty && !isRoot {
            candidates.append(dir)
        }
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
