import Foundation

/// Letar upp RW2/JPEG/DNG-filer i en given mapp (även rekursivt i undermappar om `recursive` är true).
struct PhotoScanner {
    static let rw2Extensions: Set<String> = ["rw2"]
    static let jpegExtensions: Set<String> = ["jpg", "jpeg"]
    static let dngExtensions: Set<String> = ["dng"]

    func scan(folder: URL, recursive: Bool = false,
              onFile: ((URL) -> Void)? = nil) throws -> [PhotoFile] {
        let fm = FileManager.default

        let allURLs: [URL]
        if recursive {
            var urls: [URL] = []
            let enumerator = fm.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            while let url = enumerator?.nextObject() as? URL {
                urls.append(url)
            }
            allURLs = urls
        } else {
            allURLs = try fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]
            )
        }

        var result: [PhotoFile] = []
        for url in allURLs {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }

            let ext = url.pathExtension.lowercased()
            let kind: PhotoFile.Kind?
            if PhotoScanner.rw2Extensions.contains(ext) { kind = .rw2 }
            else if PhotoScanner.jpegExtensions.contains(ext) { kind = .jpeg }
            else if PhotoScanner.dngExtensions.contains(ext) { kind = .dng }
            else { kind = nil }

            guard let kind else { continue }

            onFile?(url)

            let (date, source) = ExifReader.readCaptureDate(url: url)
            result.append(PhotoFile(url: url, kind: kind, captureDate: date, dateSource: source))
        }
        return result.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }
}
