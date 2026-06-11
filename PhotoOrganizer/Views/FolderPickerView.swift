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
    var onCleanEmpty: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Steg 1: Välj mapp") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Välj mappen med dina foton.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Välj mapp…", action: onPick)
                        if let url = selectedFolder {
                            Text(url.lastPathComponent).font(.callout)
                        }
                    }
                    if let ctx = selectedFolder.map({ FolderContext.parse(folderURL: $0) }) {
                        Text(ctx.humanDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }

            GroupBox("Steg 2: Inställningar") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Konvertera RW2 → DNG", isOn: $convertToDNG)
                        .toggleStyle(.switch)
                    Text("RW2-filer konverteras till DNG med dnglab. Originalet flyttas till papperskorgen.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)

                    Toggle("Sortera filer i datum-mappar", isOn: $sortFiles)
                        .toggleStyle(.switch)
                    Text("JPEG och DNG sorteras i YYYY/MM/DD-mappar baserat på EXIF-datum.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)

                    Toggle("Inkludera undermappar", isOn: $recurseSubfolders)
                        .toggleStyle(.switch)
                    Text("Sök även igenom alla undermappar rekursivt.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)

                    Toggle("Rensa tomma mappar efter sortering", isOn: $deleteEmptyFolders)
                        .toggleStyle(.switch)
                    Text("Efter sortering: ta bort alla tomma kataloger i mapp-trädet.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.leading, 28)
                }
                .padding(8)
            }

            GroupBox("Steg 3: Skanna") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appen söker efter RW2, JPEG och DNG-filer\(recurseSubfolders ? " i vald mapp och alla undermappar" : " (endast vald mapp)") och bygger en plan baserat på dina inställningar.")
                        .foregroundStyle(.secondary)

                    if !convertToDNG && !sortFiles {
                        Text("Aktivera minst ett alternativ ovan för att kunna skanna.")
                            .foregroundStyle(.orange).font(.callout)
                    }

                    HStack {
                        Button("Skanna och bygg plan", action: onScan)
                            .disabled(selectedFolder == nil || (!convertToDNG && !sortFiles))
                        Spacer()
                        Button("Rensa tomma mappar nu") {
                            onCleanEmpty()
                        }
                        .disabled(selectedFolder == nil)
                    }
                    if let err = scanError {
                        Text(err).foregroundStyle(.red).font(.callout)
                    }
                }
                .padding(8)
            }
        }
    }
}
