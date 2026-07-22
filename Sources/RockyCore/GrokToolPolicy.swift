import Foundation

/// Grok fires `PreToolUse` for every tool call, including read-only ones that
/// never prompt the user. Rocky auto-passes those so the notch only asks about
/// actions that need a human decision (shell, edits, network writes, etc.).
public enum GrokToolPolicy {
    /// Tools Grok treats as read-only / never-prompt by default. Keep in sync
    /// with Grok's "Operations That Never Prompt by Default" list plus Claude
    /// aliases that may appear via harness compatibility.
    public static let autoPassTools: Set<String> = [
        // Grok native
        "read_file",
        "list_dir",
        "grep",
        "web_search",
        "todo_write",
        "get_command_or_subagent_output",
        "wait_commands_or_subagents",
        "kill_command_or_subagent",
        "skill",
        "search_tool",
        // Claude-compatible aliases (Grok matcher mapping)
        "Read",
        "Grep",
        "Glob",
        "ListDir",
        "WebSearch",
        "TodoWrite",
        "Skill",
        "TaskOutput",
        "BashOutput",
        "AgentOutputTool",
    ]

    public static func shouldAutoPass(toolName: String?) -> Bool {
        guard let toolName, !toolName.isEmpty else { return false }
        return autoPassTools.contains(toolName)
    }
}
