import XCTest
@testable import PortPirateCore

final class AgentDetectorTests: XCTestCase {
  func testClassifiesClaudeCodeFromSessionEnv() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(
      envSubset: [
        "CLAUDE_CODE_SESSION_ID": "session-123",
        "CODEX_SESSION_ID": "lower-priority"
      ]
    )

    XCTAssertEqual(
      detector.classify(context),
      .aiAgent(kind: .claudeCode, sessionID: "session-123", source: .env)
    )
  }

  func testClassifiesClaudeCodeFromMarkerEnvWithoutSessionID() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(envSubset: ["CLAUDECODE": "1"])

    XCTAssertEqual(
      detector.classify(context),
      .aiAgent(kind: .claudeCode, sessionID: nil, source: .env)
    )
  }

  func testClassifiesClaudeCodeFromAIAgentEnv() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(envSubset: ["AI_AGENT": "claude-code_2-1-150_agent"])

    XCTAssertEqual(
      detector.classify(context),
      .aiAgent(kind: .claudeCode, sessionID: nil, source: .env)
    )
  }

  func testClassifiesCursorFromArguments() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(argv: ["/usr/local/bin/node", "cursor-agent", "--stdio"])

    XCTAssertEqual(detector.classify(context), .aiAgent(kind: .cursor, sessionID: nil, source: .argv))
  }

  func testClassifiesAdditionalAgentsFromEnvironment() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })

    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["OPENCODE_CONFIG": "/tmp/opencode.json"])),
      .aiAgent(kind: .opencode, sessionID: nil, source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["GEMINI_CLI_SURFACE": "terminal"])),
      .aiAgent(kind: .gemini, sessionID: nil, source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["AUGMENT_AGENT": "1"])),
      .aiAgent(kind: .augment, sessionID: nil, source: .env)
    )
  }

  func testClassifiesAdditionalAgentsFromExecutableBasename() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })

    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/opt/homebrew/bin/opencode", "run"])),
      .aiAgent(kind: .opencode, sessionID: nil, source: .argv)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["npx", "@google/gemini-cli"])),
      .aiAgent(kind: .gemini, sessionID: nil, source: .argv)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/usr/local/bin/auggie", "--print"])),
      .aiAgent(kind: .augment, sessionID: nil, source: .argv)
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

    XCTAssertEqual(
      detector.classify(context),
      .aiAgent(kind: .codex, sessionID: nil, source: .parentChain)
    )
  }

  func testEnvSourceTakesPrecedenceOverArgv() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(
      argv: ["/usr/local/bin/aider"],
      envSubset: ["CLAUDECODE": "1"]
    )

    XCTAssertEqual(
      detector.classify(context),
      .aiAgent(kind: .claudeCode, sessionID: nil, source: .env)
    )
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

  func testClassifiesAntigravityFromEnvAndArgv() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["ANTIGRAVITY_API_KEY": "x"])),
      .aiAgent(kind: .antigravity, sessionID: nil, source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/Users/me/.local/bin/agy", "run"])),
      .aiAgent(kind: .antigravity, sessionID: nil, source: .argv)
    )
  }

  func testClassifiesHermesFromSessionEnvAndArgv() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["HERMES_SESSION_ID": "sess-7"])),
      .aiAgent(kind: .hermes, sessionID: "sess-7", source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/opt/homebrew/bin/hermes", "chat"])),
      .aiAgent(kind: .hermes, sessionID: nil, source: .argv)
    )
  }

  func testOpenClawEditorExtensionLeakageDoesNotTriggerDetection() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    let context = makeContext(envSubset: [
      "OPENCLAW_COPILOT_EDITOR_VERSION": "1.95.0",
      "OPENCLAW_COPILOT_EDITOR_PLUGIN_VERSION": "0.32.0"
    ])
    XCTAssertEqual(detector.classify(context), .unknown)
  }

  func testClassifiesOpenClawFromEnvAndArgv() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["OPENCLAW_HOME": "/Users/me/.openclaw"])),
      .aiAgent(kind: .openclaw, sessionID: nil, source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(argv: ["/usr/local/bin/openclaw", "agent", "run"])),
      .aiAgent(kind: .openclaw, sessionID: nil, source: .argv)
    )
  }

  func testClassifiesGooseClineKimi() {
    let detector = AgentDetector(parentExecutableName: { _ in nil })
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["GOOSE_PROVIDER": "anthropic"])),
      .aiAgent(kind: .goose, sessionID: nil, source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["CLINE_DIR": "/tmp/cline"])),
      .aiAgent(kind: .cline, sessionID: nil, source: .env)
    )
    XCTAssertEqual(
      detector.classify(makeContext(envSubset: ["KIMI_SHARE_DIR": "/tmp/kimi"])),
      .aiAgent(kind: .kimi, sessionID: nil, source: .env)
    )
  }

  func testAgentCategoryAssignsAlwaysOnAgentsCorrectly() {
    XCTAssertEqual(AgentKind.hermes.category, .assistant)
    XCTAssertEqual(AgentKind.openclaw.category, .assistant)
    XCTAssertEqual(AgentKind.claudeCode.category, .coding)
    XCTAssertEqual(AgentKind.antigravity.category, .coding)
    XCTAssertEqual(AgentKind.goose.category, .coding)
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
