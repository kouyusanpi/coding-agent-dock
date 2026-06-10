export interface Agent {
  id: string;
  name: string;
  version: string;
  cmd: string;
  status: 'installed' | 'missing';
  icon: string;
  features: string[];
}

export interface Session {
  id: string;
  agentId: string;
  title: string;
  workspace: string;
  lastActive: string;
  historyCount: number;
  tags: string[];
}
