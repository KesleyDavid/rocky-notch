import Foundation

/// NDJSON messages between rocky-hook (client) and the app (server).
///
/// Flow: the hook sends exactly one `HookEnvelope` line. For fire-and-forget
/// events it then exits. For PermissionRequest it blocks reading one
/// `DecisionMessage` line back.
public enum IPC {
    public static let socketDirectory = "Library/Application Support/rocky"
    public static let socketName = "rocky.sock"

    /// Pre-rename install dir; the app deletes it on launch.
    public static func legacyDirectory(home: String = NSHomeDirectory()) -> String {
        (home as NSString).appendingPathComponent("Library/Application Support/vibenotch")
    }

    public static func socketPath(home: String = NSHomeDirectory()) -> String {
        (home as NSString)
            .appendingPathComponent(socketDirectory)
            .appending("/" + socketName)
    }
}

public struct HookEnvelope: Codable, Equatable, Sendable {
    public let requestId: String
    public let hookPid: Int32
    public let agent: String
    public let event: HookEvent

    public init(
        requestId: String = UUID().uuidString,
        hookPid: Int32 = ProcessInfo.processInfo.processIdentifier,
        agent: String = "claude-code",
        event: HookEvent
    ) {
        self.requestId = requestId
        self.hookPid = hookPid
        self.agent = agent
        self.event = event
    }
}

/// The four-way decision in the IPC/UI domain. At the Claude Code boundary
/// only allow/deny produce hook output; ask and passthrough both materialize
/// as "hook exits with no output" (ask = user chose the terminal,
/// passthrough = failure/timeout).
public enum Decision: String, Codable, Sendable {
    case allow
    case deny
    case ask
    case passthrough
}

public struct DecisionMessage: Codable, Equatable, Sendable {
    public let requestId: String
    public let decision: Decision
    /// Allow with modified tool input (e.g. AskUserQuestion answered from
    /// the notch: original input + the selected answers).
    public let updatedInput: JSONValue?

    public init(requestId: String, decision: Decision, updatedInput: JSONValue? = nil) {
        self.requestId = requestId
        self.decision = decision
        self.updatedInput = updatedInput
    }
}

public enum NDJSON {
    public static func encodeLine<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        try JSONDecoder().decode(type, from: line)
    }
}

/// Builds the stdout payload the hook prints back to the calling agent CLI.
public enum PermissionRequestOutput {
    /// Returns the JSON to print for allow/deny, or nil when the hook must
    /// exit silently (ask/passthrough → the agent shows its own prompt /
    /// continues fail-open).
    ///
    /// Claude Code and Codex use `hookSpecificOutput` + `behavior`.
    /// Grok's PreToolUse hooks expect `{"decision":"allow|deny"}`.
    public static func stdout(
        for decision: Decision,
        agent: String = "claude-code",
        updatedInput: JSONValue? = nil
    ) -> Data? {
        switch decision {
        case .ask, .passthrough:
            return nil
        case .allow, .deny:
            if agent == "grok" {
                return grokStdout(for: decision)
            }
            return claudeStdout(for: decision, updatedInput: updatedInput)
        }
    }

    private static func claudeStdout(
        for decision: Decision,
        updatedInput: JSONValue?
    ) -> Data? {
        var decisionObject: [String: JSONValue] = [
            "behavior": .string(decision.rawValue)
        ]
        if decision == .allow, let updatedInput {
            decisionObject["updatedInput"] = updatedInput
        }
        let payload: JSONValue = .object([
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(decisionObject),
            ])
        ])
        return encode(payload)
    }

    private static func grokStdout(for decision: Decision) -> Data? {
        var object: [String: JSONValue] = [
            "decision": .string(decision.rawValue)
        ]
        if decision == .deny {
            object["reason"] = .string("Denied in Rocky")
        }
        return encode(.object(object))
    }

    private static func encode(_ payload: JSONValue) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(payload)
    }
}
