import SwiftUI

struct PlanPreviewView: View {
    let plan: PlanBuilder.Plan
    let folderContext: FolderContext?
    let rootFolder: URL?
    @Binding var conflictDecisions: [URL: ConflictDecision]
    var onCancel: () -> Void
    var onRun: () -> Void

    private var conflicts: [PlannedOperation] {
        plan.operations.filter {
            if case .needsConflictDecision = $0 { return true }
            return false
        }
    }

    private var allConflictsResolved: Bool {
        for op in conflicts {
            if case .needsConflictDecision(let s, _, _, _) = op, conflictDecisions[s] == nil {
                return false
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryHeader

            if let ctx = folderContext {
                Text(ctx.humanDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !conflicts.isEmpty {
                conflictSection
            }

            planList

            HStack {
                Button("Avbryt", role: .cancel, action: onCancel)
                Spacer()
                Button(action: onRun) {
                    Label("Kör plan", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!allConflictsResolved)
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 20) {
            stat(title: "RW2 → DNG", count: plan.rw2Count, systemImage: "arrow.triangle.2.circlepath", color: .blue)
            stat(title: "Sorteras", count: plan.sortCount, systemImage: "folder.badge.gearshape", color: .green)
            stat(title: "Osorterade", count: plan.unsortedCount, systemImage: "questionmark.folder", color: .orange)
            stat(title: "Konflikter", count: plan.conflictCount, systemImage: "exclamationmark.triangle", color: .red)
        }
    }

    private func stat(title: String, count: Int, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading) {
            Label(title, systemImage: systemImage).foregroundStyle(color)
            Text("\(count)").font(.title).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var conflictSection: some View {
        GroupBox("Datum-konflikter – kräver ditt beslut") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mappnamnet påstår ett datum som inte stämmer med EXIF-datumet. Välj per fil:")
                    .font(.callout).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(conflicts, id: \.id) { op in
                            if case .needsConflictDecision(let s, let date, let ay, let am) = op {
                                ConflictRow(
                                    source: s,
                                    exifDate: date,
                                    assertedYear: ay,
                                    assertedMonth: am,
                                    decision: Binding(
                                        get: { conflictDecisions[s] },
                                        set: { conflictDecisions[s] = $0 }
                                    )
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding(8)
        }
    }

    private var planList: some View {
        GroupBox("Planerade operationer (\(plan.operations.count))") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.operations, id: \.id) { op in
                        PlanRow(op: op, rootFolder: rootFolder)
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 260)
        }
    }
}

private struct ConflictRow: View {
    let source: URL
    let exifDate: Date
    let assertedYear: Int?
    let assertedMonth: Int?
    @Binding var decision: ConflictDecision?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.lastPathComponent).font(.callout).bold()
                Text("EXIF-datum: \(Self.fmt(exifDate)) — mappen påstår: \(folderAssertion)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { decision ?? .moveToUnsorted },
                set: { decision = $0 }
            )) {
                Text("Använd EXIF-datum").tag(ConflictDecision.keepExifDate)
                Text("Till _unsorted/").tag(ConflictDecision.moveToUnsorted)
                Text("Hoppa över").tag(ConflictDecision.skip)
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            .opacity(decision == nil ? 0.6 : 1)
        }
        .padding(6)
        .background(decision == nil ? Color.orange.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }

    private var folderAssertion: String {
        if let y = assertedYear, let m = assertedMonth {
            return String(format: "%04d-%02d", y, m)
        } else if let y = assertedYear {
            return String(format: "%04d", y)
        }
        return "okänt"
    }

    private static func fmt(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.string(from: d)
    }
}

private struct PlanRow: View {
    let op: PlannedOperation
    let rootFolder: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var icon: some View {
        switch op {
        case .convertRW2ToDNG: Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.blue)
        case .move(_, _, let reason):
            switch reason {
            case .sortedByDate: Image(systemName: "folder.fill").foregroundStyle(.green)
            case .unsortedNoDate, .unsortedUserChoice: Image(systemName: "questionmark.folder.fill").foregroundStyle(.orange)
            }
        case .skip: Image(systemName: "minus.circle").foregroundStyle(.gray)
        case .needsConflictDecision: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private var title: String {
        switch op {
        case .convertRW2ToDNG(let s, _, let trash):
            return "Konvertera \(s.lastPathComponent)\(trash ? " (RW2 → papperskorg)" : "")"
        case .move(let s, let d, _):
            return "\(s.lastPathComponent) → \(relative(d))"
        case .skip(let s, let reason):
            return "Hoppa över \(s.lastPathComponent) (\(reason))"
        case .needsConflictDecision(let s, _, _, _):
            return "\(s.lastPathComponent) — beslut krävs"
        }
    }

    private var detail: String? {
        switch op {
        case .move(_, _, .unsortedNoDate): return "Saknar EXIF-datum → _unsorted/"
        case .move(_, _, .unsortedUserChoice): return "Användarval: _unsorted/"
        case .move(_, _, .sortedByDate(let d)):
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            return "Datum: \(df.string(from: d))"
        default: return nil
        }
    }

    private func relative(_ url: URL) -> String {
        guard let root = rootFolder else { return url.path }
        let rootPath = root.path
        if url.path.hasPrefix(rootPath) {
            return String(url.path.dropFirst(rootPath.count).drop(while: { $0 == "/" }))
        }
        return url.path
    }
}
