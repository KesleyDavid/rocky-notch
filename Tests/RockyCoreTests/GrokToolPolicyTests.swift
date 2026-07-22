import XCTest
@testable import RockyCore

final class GrokToolPolicyTests: XCTestCase {
    func testAutoPassesReadOnlyTools() {
        for name in ["read_file", "Read", "grep", "list_dir", "todo_write", "web_search"] {
            XCTAssertTrue(GrokToolPolicy.shouldAutoPass(toolName: name), name)
        }
    }

    func testDoesNotAutoPassWriteOrShell() {
        for name in [
            "run_terminal_command", "Bash", "search_replace", "Edit",
            "write", "Write", "spawn_subagent", "use_tool",
        ] {
            XCTAssertFalse(GrokToolPolicy.shouldAutoPass(toolName: name), name)
        }
    }

    func testNilAndEmpty() {
        XCTAssertFalse(GrokToolPolicy.shouldAutoPass(toolName: nil))
        XCTAssertFalse(GrokToolPolicy.shouldAutoPass(toolName: ""))
    }
}
