import SwiftUI

// MARK: - Security View

struct SecurityView: View {
    let project: Project
    @State private var findings: [SecurityFinding] = []
    @State private var isScanning: Bool = false
    @State private var hasScanned: Bool = false

    private let scanner = SecurityScanner()

    var criticalCount: Int { findings.filter { $0.severity == .critical }.count }
    var highCount:     Int { findings.filter { $0.severity == .high }.count }
    var score: Int {
        let deductions = findings.reduce(0) { acc, f in
            switch f.severity {
            case .critical: return acc + 30
            case .high:     return acc + 15
            case .medium:   return acc + 5
            case .info:     return acc + 0
            }
        }
        return max(0, 100 - deductions)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningState
            } else if !hasScanned {
                idleState
            } else if findings.isEmpty {
                cleanState
            } else {
                findingsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - States

    private var idleState: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Análise de Segurança")
                .font(.title3.bold())

            Text("Verifica segredos expostos, ficheiros sensíveis tracked, padrões perigosos no código e higiene do git.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            Button("Analisar Agora") {
                Task { await runScan() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("A analisar ficheiros, git e código…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("A verificar padrões de segredos, ficheiros tracked, histórico git.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(60)
        .frame(maxWidth: .infinity)
    }

    private var cleanState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Nenhum problema encontrado")
                .font(.title3.bold())
            Text("O projecto passa em todas as verificações de segurança.")
                .foregroundStyle(.secondary)
            Button("Reanalisar") { Task { await runScan() } }
                .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Findings list

    private var findingsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Score header
            HStack(spacing: 20) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Score de Segurança")
                        .font(.headline)
                    HStack(spacing: 12) {
                        if criticalCount > 0 {
                            Label("\(criticalCount) crítico\(criticalCount > 1 ? "s" : "")", systemImage: "xmark.octagon.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if highCount > 0 {
                            Label("\(highCount) alto\(highCount > 1 ? "s" : "")", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text("\(findings.count) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Reanalisar") { Task { await runScan() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(20)
            .background(.quinary)

            Divider()

            // Grouped by category
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    let grouped = Dictionary(grouping: findings, by: \.category)
                    ForEach(SecurityFinding.Category.allCases, id: \.self) { cat in
                        if let items = grouped[cat], !items.isEmpty {
                            Section {
                                ForEach(items) { finding in
                                    FindingRow(finding: finding)
                                    if finding.id != items.last?.id { Divider().padding(.leading, 52) }
                                }
                            } header: {
                                Text(cat.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.windowBackground)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    private var scoreColor: Color {
        switch score {
        case 80...: return .green
        case 50...79: return .orange
        default:    return .red
        }
    }

    // MARK: - Scan

    private func runScan() async {
        isScanning = true
        findings = await scanner.scan(project)
        hasScanned = true
        isScanning = false
    }
}

// MARK: - Finding Row

struct FindingRow: View {
    let finding: SecurityFinding
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: finding.severity.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: finding.severity.color))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(finding.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(finding.severity.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: finding.severity.color))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: finding.severity.color).opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Text(finding.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text(finding.recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 52)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Category + CaseIterable

extension SecurityFinding.Category: CaseIterable {
    public static var allCases: [SecurityFinding.Category] {
        [.secrets, .gitHygiene, .dependencies, .structure, .bestPractice]
    }
}
