import SwiftUI
import VibenotchCore

/// The black shape that hugs the notch. Collapsed: status indicators in
/// "wings" beside the notch. Expanded: session list with the approval card.
struct NotchView: View {
    @ObservedObject var hub: AgentHub
    @ObservedObject var state: NotchUIState

    static let expandedWidth: CGFloat = 400
    static let rowHeight: CGFloat = 44
    static let cardHeight: CGFloat = 100
    static let wingWidth: CGFloat = 70

    static func size(
        expanded: Bool,
        sessionCount: Int,
        hasPending: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> CGSize {
        if !expanded {
            return CGSize(width: notchWidth + wingWidth * 2, height: notchHeight)
        }
        let rows = CGFloat(max(sessionCount, 1)) * rowHeight
        let card: CGFloat = hasPending ? cardHeight : 0
        let height = notchHeight + rows + card + 16
        return CGSize(
            width: max(expandedWidth, notchWidth + wingWidth * 2),
            height: min(height, 480)
        )
    }

    private var hasPending: Bool {
        hub.sessions.contains { $0.pending != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.expanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                collapsedContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: state.expanded)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: hub.sessions.map(\.id))
        .onHover { hovering in
            // Expansion/collapse authority lives in NotchWindowController;
            // the view only reports raw hover.
            if state.hovering != hovering { state.hovering = hovering }
        }
    }

    private var background: some View {
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16),
            style: .continuous
        )
        return ZStack {
            shape.fill(.black)
            if state.expanded {
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            if hasPending {
                shape
                    .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                    .blur(radius: 2)
                    .breathing(period: 1.4)
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(state.expanded ? 0.5 : 0), radius: 18, y: 8)
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
        HStack {
            // Left wing: aggregated activity (equalizer while anything runs).
            HStack {
                if hub.sessions.contains(where: { $0.status == .running }) {
                    EqualizerBars(color: .green)
                        .frame(width: 16, height: 10)
                }
            }
            .padding(.leading, 16)
            .frame(width: Self.wingWidth, alignment: .leading)

            Spacer()

            // Right wing: one dot per session.
            HStack(spacing: 5) {
                if hub.sessions.isEmpty {
                    Circle().fill(Color.white.opacity(0.25)).frame(width: 5, height: 5)
                } else {
                    ForEach(hub.sessions.prefix(6)) { session in
                        StatusDot(status: session.status)
                    }
                }
            }
            .padding(.trailing, 16)
            .frame(width: Self.wingWidth, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 8)
            if hub.sessions.isEmpty {
                Text("nenhuma sessão ativa")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
            } else {
                ForEach(hub.sessions) { session in
                    SessionRow(session: session, hub: hub)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            Color.clear.frame(height: 8)
        }
        .padding(.top, 30)
        .padding(.horizontal, 14)
        .colorScheme(.dark)
    }
}

// MARK: - Animated primitives

/// Gentle infinite pulse (opacity + scale) for "needs attention" accents.
private struct BreathingModifier: ViewModifier {
    let period: Double
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.35 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: period).repeatForever()) {
                    dimmed = true
                }
            }
    }
}

extension View {
    func breathing(period: Double = 1.2) -> some View {
        modifier(BreathingModifier(period: period))
    }
}

/// Tiny audio-style equalizer — the "agent is vibing" signature mark.
struct EqualizerBars: View {
    var color: Color
    var barCount: Int = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = t * 2.4 + Double(index) * 1.7
                    let height = 0.35 + 0.65 * abs(sin(phase))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(height: 10 * height)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }
}

struct StatusDot: View {
    let status: AgentSession.Status

    var color: Color {
        switch status {
        case .running: .green
        case .waitingPermission: .orange
        case .waitingInput: .yellow
        case .idle: .gray
        }
    }

    private var needsAttention: Bool {
        status == .waitingPermission || status == .waitingInput
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.9), radius: needsAttention ? 4 : 2)
            .breathing(period: needsAttention ? 0.8 : 2.6)
    }
}

struct SessionRow: View {
    let session: AgentSession
    @ObservedObject var hub: AgentHub
    @State private var hoveringTerminal = false

    var statusText: String {
        switch session.status {
        case .running: "rodando"
        case .waitingPermission: "pedindo permissão"
        case .waitingInput: "esperando você"
        case .idle: "terminou"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if session.status == .running {
                    EqualizerBars(color: .green)
                        .frame(width: 14, height: 10)
                } else {
                    StatusDot(status: session.status)
                }
                Text(session.projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if session.agent != "claude-code" {
                    Text(session.agent)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .foregroundStyle(.white.opacity(0.7))
                }
                if session.status == .running, let action = session.lastAction {
                    Text(action)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .id(action)
                        .transition(.opacity)
                } else {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    TerminalFocus.focus(session: session)
                } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                        .foregroundStyle(hoveringTerminal ? .white : .secondary)
                        .scaleEffect(hoveringTerminal ? 1.15 : 1)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(duration: 0.2)) { hoveringTerminal = hovering }
                }
                .help("ir para o terminal")
            }
            .frame(height: NotchView.rowHeight - 14)

            if let pending = session.pending {
                PermissionCard(pending: pending, hub: hub)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: session.pending)
        .animation(.easeInOut(duration: 0.25), value: session.lastAction)
    }
}

struct PermissionCard: View {
    let pending: PendingPermission
    @ObservedObject var hub: AgentHub

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .breathing(period: 1.0)
                Text(pending.toolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
                TimeoutRing(since: pending.receivedAt, total: 55)
                    .frame(width: 12, height: 12)
            }
            Text(pending.summary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                DecisionButton(title: "Aprovar", tint: .green) {
                    hub.decide(requestId: pending.requestId, decision: .allow)
                }
                DecisionButton(title: "Negar", tint: .red) {
                    hub.decide(requestId: pending.requestId, decision: .deny)
                }
                DecisionButton(title: "No terminal", tint: .white.opacity(0.7)) {
                    hub.decide(requestId: pending.requestId, decision: .ask)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.bottom, 6)
    }
}

/// Countdown ring for the pending decision (visual, approximate).
struct TimeoutRing: View {
    let since: Date
    let total: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(since)
            let remaining = max(0, 1 - elapsed / total)
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                .overlay(
                    Circle()
                        .trim(from: 0, to: remaining)
                        .stroke(
                            remaining < 0.25 ? Color.red : Color.orange,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                )
        }
    }
}

struct DecisionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(tint.opacity(hovering ? 0.45 : 0.22))
                )
                .overlay(
                    Capsule().strokeBorder(tint.opacity(hovering ? 0.8 : 0.3), lineWidth: 1)
                )
                .foregroundStyle(tint)
                .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(duration: 0.18)) { hovering = h }
        }
    }
}
