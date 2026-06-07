import Foundation

/// Wrapper runt dnglab – en open source RAW-till-DNG-konverterare som bundlas i appen.
/// Binären finns på: <App>.app/Contents/Resources/dnglab
///
/// Kommandorad: dnglab convert [OPTIONS] <INPUT> <OUTPUT>
struct DNGConverter {

    enum ConvertError: Error, LocalizedError {
        case binaryMissing
        case conversionFailed(exitCode: Int32, stderr: String)
        case outputMissing(expected: URL)
        case metadataMissing(URL)

        var errorDescription: String? {
            switch self {
            case .binaryMissing:
                return "Kunde inte hitta den inbakade dnglab-binären i appen."
            case .conversionFailed(let code, let err):
                return "dnglab misslyckades (exit \(code)): \(err)"
            case .outputMissing(let url):
                return "DNG-filen skapades inte: \(url.path)"
            case .metadataMissing(let url):
                return "Metadata saknas eller kunde inte läsas i konverterad DNG: \(url.path)"
            }
        }
    }

    /// Sökväg till inbakad dnglab-binär.
    static var binaryURL: URL? {
        Bundle.main.url(forResource: "dnglab", withExtension: nil)
    }

    /// Konverterar `source` (RW2) till DNG i samma mapp. Returnerar URL till DNG-filen.
    func convert(source: URL) throws -> URL {
        guard let bin = DNGConverter.binaryURL,
              FileManager.default.isExecutableFile(atPath: bin.path) else {
            throw ConvertError.binaryMissing
        }

        let destDir = source.deletingLastPathComponent()
        let baseName = source.deletingPathExtension().lastPathComponent
        let dngURL = destDir.appendingPathComponent("\(baseName).dng")

        let process = Process()
        process.executableURL = bin
        process.arguments = [
            "convert",
            "--compression", "lossless",
            "--embed-raw", "true",
            "--dng-preview", "true",
            "--dng-thumbnail", "true",
            "-f",                    // överskriv om filen redan finns
            source.path,
            dngURL.path
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw ConvertError.conversionFailed(exitCode: process.terminationStatus, stderr: errStr)
        }

        guard FileManager.default.fileExists(atPath: dngURL.path) else {
            throw ConvertError.outputMissing(expected: dngURL)
        }

        // Verifiera att metadata (datum) överlevde konverteringen
        guard ExifReader.verifyDNG(url: dngURL) else {
            throw ConvertError.metadataMissing(dngURL)
        }

        return dngURL
    }
}
