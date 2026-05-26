import XCTest
@testable import PortPirateCore

final class AgentDetectorTests: XCTestCase {
  func testClassifiesClaudeCodeFromEnvironment() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(
      envSubset: [
        "CLAUDE_CODE_SESSION_ID": "session-123",
        "CODEX_SESSION_ID": "lower-priority"
      ]
    )

    XCTAssertEqual(
      detector.classify(context),
      .aiAgent(kind: .claudeCode, sessionID: "session-123")
    )
  }

  func testClassifiesCursorFromArguments() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(argv: ["/usr/local/bin/node", "cursor-agent", "--stdio"])

    XCTAssertEqual(detector.classify(context), .aiAgent(kind: .cursor, sessionID: nil))
  }

  func testClassifiesAdditionalAgentsFromEnvironment() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })

    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["OPENCODE_CONFIG": "/tmp/opencode.json"])),
      .aiAgent(kind: .opencode, sessionID: nil)
    )
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["GEMINI_CLI_SURFACE": "terminal"])),
      .aiAgent(kind: .gemini, sessionID: nil)
    )
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["AUGMENT_AGENT": "1"])),
      .aiAgent(kind: .augment, sessionID: nil)
    )
  }

  func testClassifiesAdditionalAgentsFromExecutableBasename() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })

    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/opt/homebrew/bin/opencode", "run"])),
      .aiAgent(kind: .opencode, sessionID: nil)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["npx", "@google/gemini-cli"])),
      .aiAgent(kind: .gemini, sessionID: nil)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/usr/local/bin/auggie", "--print"])),
      .aiAgent(kind: .augment, sessionID: nil)
    )
  }

  func testArgumentClassificationDoesNotSearchFullCommandLineText() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(argv: ["/usr/bin/python3", "/Users/claude/project/server.py", "--header", "x-claude:foo"])

    XCTAssertEqual(detector.classify(context), .unknown)
  }

  func testClassifiesCodexFromParentExecutable() {
    let detector = AgentDetector { pid in
      pid == 42 ? "Codex" : nil
    }
    let context = makeContext(ppidChain: [100, 42, 1])

    XCTAssertEqual(detector.classify(context), .aiAgent(kind: .codex, sessionID: nil))
  }

  func testVSCodeEditorParentIsNotAnAIAgent() {
    let detector = AgentDetector { pid in
      pid == 42 ? "code-insiders" : nil
    }
    let context = makeContext(ppidChain: [100, 42, 1])

    XCTAssertEqual(detector.classify(context), .unknown)
  }

  func testClassifiesManualFromInteractiveShellParent() {
    let detector = AgentDetector { pid in
      pid == 42 ? "zsh" : nil
    }
    let context = makeContext(ppidChain: [100, 42, 1])

    XCTAssertEqual(detector.classify(context), .manual)
  }

  func testClassifiesUnknownWithoutSignals() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })

    XCTAssertEqual(detector.classify(makeContext()), .unknown)
  }

  private func makeContext(
    pid: pid_t = 100,
    ppidChain: [pid_t] = [100, 1],
    cwd: String? = nil,
    executablePath: String? = nil,
    argv: [String] = [],
    envSubset: [String: String] = [:],
    startedAt: Date? = nil
  ) -> ProcessContext {
    ProcessContext(
      pid: pid,
      ppidChain: ppidChain,
      cwd: cwd,
      executablePath: executablePath,
      argv: argv,
      envSubset: envSubset,
      startedAt: startedAt
    )
  }
}
