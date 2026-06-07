import SwiftUI

struct ProgressOverlayView: View {
    @ObservedObject var runner: OperationRunner

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(runner.currentPhase).font(.headline)
            ProgressView(value: runner.progressValue, total: max(runner.progressTotal, 1))
                .progressViewStyle(.linear)
            HStack {
                Text("\(Int(runner.progressValue)) / \(Int(runner.progressTotal))")
                    .foregroundStyle(.secondary).font(.callout)
                Spacer()
                Button("Avbryt", role: .destructive) { runner.cancel() }
            }
        }
        .padding(16)
        .background(Color(NSColor.underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
