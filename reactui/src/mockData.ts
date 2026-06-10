import { Agent, Session } from './types';

export const mockAgents: Agent[] = [
  { id: 'aider', name: 'Aider', version: 'v0.50.1', cmd: 'aider', status: 'installed', icon: 'Terminal', features: ['Git Integration', 'Architect Mode', 'Auto Commit'] },
  { id: 'cline', name: 'Cline', version: 'v1.4.0', cmd: 'cline', status: 'installed', icon: 'Sparkles', features: ['MCP Tools Support', 'VSCode Extension', 'Complex Workflows'] },
  { id: 'cursor', name: 'Cursor AI', version: 'v0.40.4', cmd: 'cursor', status: 'installed', icon: 'TextCursor', features: ['Composer', 'Cmd-K Generation', 'Inline Edits'] },
  { id: 'autocoder', name: 'AutoCoder', version: 'v1.0.0', cmd: 'autocoder', status: 'missing', icon: 'Cpu', features: ['Code Review', 'CI/CD Int', 'Doc Gen'] },
];

export const mockSessions: Session[] = [
  { id: 's1', agentId: 'aider', title: 'Refactor Express Router', workspace: '~/projects/api-server', lastActive: '2 mins ago', historyCount: 15, tags: ['node', 'refactor'] },
  { id: 's2', agentId: 'aider', title: 'Implement Auth Middleware', workspace: '~/projects/api-server', lastActive: '1 hr ago', historyCount: 8, tags: ['security'] },
  { id: 's3', agentId: 'cline', title: 'Build React Dashboard UI', workspace: '~/projects/admin-dashboard', lastActive: 'Yesterday', historyCount: 32, tags: ['react', 'tailwind'] },
  { id: 's4', agentId: 'cursor', title: 'Migrate to Next.js', workspace: '~/projects/marketing-site', lastActive: '3 days ago', historyCount: 112, tags: ['nextjs', 'migration'] },
  { id: 's5', agentId: 'cline', title: 'Fix CSS Grid Layout Bugs', workspace: '~/projects/admin-dashboard', lastActive: '4 days ago', historyCount: 5, tags: ['css'] },
];
