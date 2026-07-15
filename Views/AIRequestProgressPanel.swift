import SwiftUI

struct AIRequestProgressPanel: View {
    let entries: [AIRequestProgressEntry]
    let isActive: Bool

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("API progress", systemImage: "list.bullet.clipboard")
                        .font(.caption.weight(.semibold))

                    Spacer()

                    if isActive {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ForEach(entries) { entry in
                    AIRequestProgressRow(entry: entry)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct AIRequestProgressRow: View {
    let entry: AIRequestProgressEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.event.title)
                    .font(.caption)
                    .foregroundStyle(.primary)

                if let detail = entry.event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var iconName: String {
        switch entry.event.kind {
        case .active:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch entry.event.kind {
        case .active:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .failure:
            return .red
        }
    }
}
