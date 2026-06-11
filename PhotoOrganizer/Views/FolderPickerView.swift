import SwiftUI

struct FolderPickerView: View {
    @Binding var selectedFolder: URL?
    @Binding var scanError: String?
    @Binding var convertToDNG: Bool
    @Binding var sortFiles: Bool
    @Binding var recurseSubfolders: Bool
    @Binding var deleteEmptyFolders: Bool
    var onPick: () -> Void
    var onScan: () -> Void

    private var anyActive: Bool {
        convertToDNG || sortFiles || deleteEmptyFolders
    }

    private var actionLabel: String {
        var parts: [String] = []
        if convertToDNG { parts.append("konvertera") }
        if sortFiles { parts.append("sortera") }
        if deleteEmptyFolders { parts.append("rensa tomma mappar") }
        return parts.joined(separator: " och ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("1. Välj mapp") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("Välj mapp…", action: onPick)
                        if let url = selectedFolder {
                            Text(url.lastPathComponent)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if selectedFolder == nil {
                        Text("Välj en mapp för att komma igång.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }

            GroupBox("2. Vad vill du göra?") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Konvertera RW2 → DNG", isOn: $convertToDNG)
                        .toggleStyle(.switch)
                    Text("RW2-konvertering med dnglab. Originalet hamnar i papperskorgen.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)

                    Toggle("Sortera filer i YYYY/MM/DD", isOn: $sortFiles)
                        .toggleStyle(.switch)
                    Text("JPEG och DNG sorteras i datum-mappar efter EXIF-datum.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)

                    Toggle("Rensa tomma mappar", isOn: $deleteEmptyFolders)
                        .toggleStyle(.switch)
                    Text("Ta bort alla tomma kataloger i mapp-trädet.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)

                    Toggle("Inkludera undermappar", isOn: $recurseSubfolders)
                        .toggleStyle(.switch)
                    Text("Sök även i undermappar (gäller konvertering och sortering).")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)
                }
                .padding(8)
            }

            GroupBox("3. Starta") {
                VStack(alignment: .leading, spacing: 12) {
                    if anyActive {
                        Text("Kommer att \(actionLabel) i \"\(selectedFolder?.lastPathComponent ?? "…")\".")
                            .foregroundStyle(.secondary)
                    }

                    if !anyActive {
                        Text("Välj minst ett alternativ ovan.")
                            .foregroundStyle(.orange)
                    }

                    Button(action: onScan) {
                        Label("Starta", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedFolder == nil || !anyActive)

                    if let err = scanError {
                        Text(err).foregroundStyle(.red).font(.callout)
                    }
                }
                .padding(12)
            }
        }
    }
}
