import SwiftUI

struct ScanningOverlay: View {
    @Binding var fileName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(0.8)
                    .controlSize(.small)
                Text("Skannar mapp...")
                    .font(.headline)
            }

            if let f = fileName {
                Text(f)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(20)
        .background(Color(NSColor.underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
