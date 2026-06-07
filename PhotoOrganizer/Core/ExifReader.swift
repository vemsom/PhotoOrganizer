import Foundation
import ImageIO

/// Läser EXIF-datum via ImageIO. Fungerar för JPEG och DNG. För RW2 försöker vi också,
/// men Panasonic-filer öppnas inte alltid av ImageIO – i så fall returneras nil.
enum ExifReader {
    /// Returnerar (datum, källa). Källa är .none om inget hittades.
    static func readCaptureDate(url: URL) -> (Date?, PhotoFile.DateSource) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return (nil, .none)
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return (nil, .none)
        }

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

        if let s = exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
           let d = parseExifDate(s) {
            return (d, .exifOriginal)
        }
        if let s = exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
           let d = parseExifDate(s) {
            return (d, .exifDigitized)
        }
        if let s = tiff?[kCGImagePropertyTIFFDateTime] as? String,
           let d = parseExifDate(s) {
            return (d, .tiffDateTime)
        }
        return (nil, .none)
    }

    /// EXIF-datum har formen "YYYY:MM:DD HH:MM:SS".
    static func parseExifDate(_ s: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return df.date(from: s)
    }

    /// Verifierar att en DNG-fil kan läsas och har ett datum.
    static func verifyDNG(url: URL) -> Bool {
        let (date, _) = readCaptureDate(url: url)
        return date != nil
    }
}
