import 'agent_cli.dart';

/// Registry of known AI programming agent CLIs to detect.
///
/// Each entry defines the CLI's metadata and detection strategy:
/// - [binaryName]: primary binary to look for via `which`
/// - [aliases]: fallback binary names
/// - [versionFlag]: the flag used to query version (--version, version, -V, -v)
/// - [commonPaths]: common install locations — listed highest-priority-first
/// - [installHint]: shown in the UI when the CLI is not detected
class CliRegistry {
  CliRegistry._();

  /// All known agent CLIs in detection order.
  static List<AgentCli> createAll() {
    final now = DateTime.now();
    return [
      // --- Anthropic ---
      AgentCli(
        id: 'claude',
        displayName: 'Claude Code',
        binaryName: 'claude',
        aliases: ['claude-code'],
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          r'$HOME/.local/bin/claude',
          r'$HOME/.local/share/claude/versions/current/bin/claude',
          '/usr/local/bin/claude',
          '/opt/homebrew/bin/claude',
          '/usr/local/bin/claude-code',
        ],
        npmPackage: '@anthropic-ai/claude-code',
        installHint: 'npm install -g @anthropic-ai/claude-code\n'
            '# or via the official installer:\n'
            'curl -fsSL https://claude.ai/install.sh | sh',
      ),

      // --- OpenAI ---
      AgentCli(
        id: 'codex',
        displayName: 'OpenAI Codex CLI',
        binaryName: 'codex',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/codex',
          '/opt/homebrew/bin/codex',
          r'$HOME/.local/bin/codex',
        ],
        npmPackage: '@openai/codex',
        installHint: 'npm install -g @openai/codex',
      ),

      // --- CodeWhale ---
      AgentCli(
        id: 'codewhale',
        displayName: 'CodeWhale',
        binaryName: 'codewhale',
        aliases: ['cw'],
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/codewhale',
          '/opt/homebrew/bin/codewhale',
          r'$HOME/.cargo/bin/codewhale',
        ],
        installHint: 'cargo install codewhale',
      ),

      // --- Google ---
      AgentCli(
        id: 'gemini',
        displayName: 'Gemini CLI',
        binaryName: 'gemini',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/gemini',
          '/opt/homebrew/bin/gemini',
          r'$HOME/.local/bin/gemini',
        ],
        npmPackage: '@google/gemini-cli',
        installHint: 'npm install -g @google/gemini-cli',
      ),

      // --- GitHub ---
      AgentCli(
        id: 'gh-copilot',
        displayName: 'GitHub Copilot',
        binaryName: 'gh',
        versionFlag: 'copilot --version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/gh',
          '/opt/homebrew/bin/gh',
        ],
        installHint: 'brew install gh\ngh extension install github/gh-copilot',
      ),

      // --- Aider ---
      AgentCli(
        id: 'aider',
        displayName: 'Aider',
        binaryName: 'aider',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/aider',
          '/opt/homebrew/bin/aider',
          r'$HOME/.local/bin/aider',
        ],
        pipPackage: 'aider-chat',
        installHint: 'pip install aider-install\naider-install',
      ),

      // --- Cursor CLI ---
      AgentCli(
        id: 'cursor',
        displayName: 'Cursor CLI',
        binaryName: 'cursor',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/cursor',
          '/opt/homebrew/bin/cursor',
        ],
        installHint: 'Install Cursor from https://cursor.sh\n'
            'Then enable CLI: Cmd+Shift+P → "Install cursor command"',
      ),

      // --- Windsurf ---
      AgentCli(
        id: 'windsurf',
        displayName: 'Windsurf',
        binaryName: 'windsurf',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/windsurf',
          '/opt/homebrew/bin/windsurf',
        ],
        installHint:
            'Install Windsurf from https://codeium.com/windsurf',
      ),

      // --- Continue ---
      AgentCli(
        id: 'continue',
        displayName: 'Continue CLI',
        binaryName: 'continue',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/continue',
          '/opt/homebrew/bin/continue',
        ],
        npmPackage: '@continuedev/cli',
        installHint: 'npm install -g @continuedev/cli',
      ),

      // --- Amazon Web Services ---
      AgentCli(
        id: 'amazon-q',
        displayName: 'Amazon Q Developer',
        binaryName: 'q',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/q',
          '/opt/homebrew/bin/q',
          r'$HOME/.local/bin/q',
          r'$HOME/Library/Application Support/codewhisperer/bin/q',
        ],
        installHint: 'brew install amazon-q\n'
            '# or download from https://aws.amazon.com/q/developer/',
      ),

      // --- Open Interpreter ---
      AgentCli(
        id: 'interpreter',
        displayName: 'Open Interpreter',
        binaryName: 'interpreter',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/interpreter',
          '/opt/homebrew/bin/interpreter',
          r'$HOME/.local/bin/interpreter',
          r'$HOME/Library/Python/3.13/bin/interpreter',
          r'$HOME/Library/Python/3.12/bin/interpreter',
          r'$HOME/Library/Python/3.11/bin/interpreter',
          r'$HOME/Library/Python/3.10/bin/interpreter',
        ],
        pipPackage: 'open-interpreter',
        installHint: 'pip install open-interpreter\n'
            '# or with pipx:\n'
            'pipx install open-interpreter',
      ),

      // --- GPT Engineer ---
      AgentCli(
        id: 'gpt-engineer',
        displayName: 'GPT Engineer',
        binaryName: 'gpte',
        aliases: ['gpt-engineer'],
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/gpte',
          '/opt/homebrew/bin/gpte',
          r'$HOME/.local/bin/gpte',
          r'$HOME/Library/Python/3.12/bin/gpte',
          r'$HOME/Library/Python/3.11/bin/gpte',
        ],
        pipPackage: 'gpt-engineer',
        installHint: 'pip install gpt-engineer\n'
            '# or with pipx:\n'
            'pipx install gpt-engineer',
      ),

      // --- Goose (Block) ---
      AgentCli(
        id: 'goose',
        displayName: 'Goose',
        binaryName: 'goose',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/goose',
          '/opt/homebrew/bin/goose',
          r'$HOME/.local/bin/goose',
          r'$HOME/.goose/bin/goose',
        ],
        installHint: 'curl -fsSL https://github.com/block/goose/releases/latest/download/install.sh | sh',
      ),

      // --- Plandex ---
      AgentCli(
        id: 'plandex',
        displayName: 'Plandex',
        binaryName: 'plandex',
        aliases: ['pdx'],
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/plandex',
          '/opt/homebrew/bin/plandex',
          r'$HOME/.local/bin/plandex',
        ],
        installHint: 'curl -sL https://plandex.ai/install.sh | bash',
      ),

      // --- Amp (Sourcegraph) ---
      AgentCli(
        id: 'amp',
        displayName: 'Amp',
        binaryName: 'amp',
        versionFlag: '--version',
        lastChecked: now,
        commonPaths: [
          '/usr/local/bin/amp',
          '/opt/homebrew/bin/amp',
          r'$HOME/.local/bin/amp',
        ],
        installHint: 'npm install -g @sourcegraph/amp',
        npmPackage: '@sourcegraph/amp',
      ),
    ];
  }
}
