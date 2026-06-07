import SwiftUI
import AppKit

@main
struct PhotoOrganizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .help) {
                Divider()
                Button("Om PhotoOrganizer") {
                    let alert = NSAlert()
                    alert.messageText = "PhotoOrganizer"
                    alert.informativeText = """
                    Konverterar RW2 → DNG med dnglab (metadata bevaras)
                    Sorterar JPEG och DNG i YYYY/MM/DD-struktur baserat på EXIF-datum
                    RW2-originalen flyttas till papperskorgen efter lyckad konvertering
                    Konvertering och sortering kan aktiveras/inaktiveras oberoende
                    Kan söka igenom undermappar rekursivt
                    Inget skrivs till disk förrän du godkänner planen
                    """
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            }
        }
    }
}
