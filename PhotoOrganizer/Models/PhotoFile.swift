import Foundation

/// En fil som appen tagit hänsyn till.
struct PhotoFile: Hashable, Identifiable {
    enum Kind: String {
        case rw2
        case jpeg
        case dng
    }

    var id: URL { url }
    let url: URL
    let kind: Kind
    /// EXIF DateTimeOriginal (eller fallback-källor), om tillgängligt.
    let captureDate: Date?
    /// Informativ beskrivning av vilken källa datumet kom ifrån.
    let dateSource: DateSource

    enum DateSource: String {
        case exifOriginal = "EXIF DateTimeOriginal"
        case exifDigitized = "EXIF DateTimeDigitized"
        case tiffDateTime = "TIFF DateTime"
        case none = "Saknas"
    }

    var filename: String { url.lastPathComponent }
}
