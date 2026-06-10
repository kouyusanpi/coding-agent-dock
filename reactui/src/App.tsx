import React, { useState, useMemo, useEffect } from 'react';
import { 
  Search, 
  Terminal, 
  Sparkles, 
  TextCursor, 
  Cpu, 
  Play, 
  Clock, 
  Folder, 
  CheckCircle2, 
  AlertCircle,
  Command,
  MonitorSmartphone,
  Tag,
  ChevronRight,
  RefreshCw,
  LogOut,
  X,
  XCircle
} from 'lucide-react';
import { mockAgents, mockSessions } from './mockData';
import { Agent, Session } from './types';
import { motion, AnimatePresence } from 'motion/react';

const iconMap: Record<string, React.ElementType> = {
  Terminal, Sparkles, TextCursor, Cpu
};

function SearchBar({ searchQuery, setSearchQuery }: { searchQuery: string, setSearchQuery: (q: string) => void }) {
  return (
    <div className="relative w-full max-w-md mx-auto group">
      <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
        <Search className="h-4 w-4 text-gray-400 group-focus-within:text-blue-500 transition-colors" />
      </div>
      <input
        type="text"
        className="block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg leading-5 bg-gray-800 text-gray-200 placeholder-gray-400 focus:outline-none focus:bg-gray-900 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm transition-all"
        placeholder="Search sessions, tags, or workspaces... (Cmd + K)"
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
      />
      <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
        <kbd className="hidden sm:inline-block border border-gray-700 rounded-md px-2 text-xs text-gray-500 bg-gray-800">
          ⌘K
        </kbd>
      </div>
    </div>
  );
}

export default function App() {
  const [selectedAgentId, setSelectedAgentId] = useState<string | null>(mockAgents[0].id);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeSession, setActiveSession] = useState<Session | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [isCreatingSession, setIsCreatingSession] = useState(false);
  const [localAgents, setLocalAgents] = useState<Agent[]>(mockAgents);
  const [sessions, setSessions] = useState<Session[]>(mockSessions);
  const [newSessionMeta, setNewSessionMeta] = useState({ workspace: '~/projects/new-project', title: '' });

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        document.querySelector('input')?.focus();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleScan = () => {
    setIsScanning(true);
    setTimeout(() => {
      setIsScanning(false);
      setLocalAgents([...mockAgents]);
    }, 1200);
  };

  const filteredSessions = useMemo(() => {
    return sessions.filter(session => {
      const matchesSearch = 
        session.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        session.workspace.toLowerCase().includes(searchQuery.toLowerCase()) ||
        session.tags.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()));
      
      const matchesAgent = searchQuery ? true : session.agentId === selectedAgentId;
      
      return matchesSearch && (searchQuery ? matchesSearch : matchesAgent);
    });
  }, [searchQuery, selectedAgentId]);

  return (
    <div className="flex h-screen bg-gray-950 text-gray-100 overflow-hidden font-sans selection:bg-blue-500/30">
      
      {/* Sidebar */}
      <div className="w-64 bg-gray-900/50 border-r border-gray-800 flex flex-col shrink-0 relative z-10 backdrop-blur-xl">
        <div className="h-14 flex items-center px-4 border-b border-gray-800">
          <MonitorSmartphone className="w-5 h-5 text-blue-400 mr-2" />
          <span className="font-semibold tracking-tight text-gray-100">AgentOS CLI</span>
        </div>
        
        <div className="flex-1 overflow-y-auto py-4">
          <div className="px-3 mb-2 flex items-center justify-between">
            <h2 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Local Environments</h2>
            <button 
              onClick={handleScan}
              className={`text-gray-500 hover:text-gray-300 transition-colors ${isScanning ? 'animate-spin' : ''}`}
              title="Rescan Local CLIs"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
          </div>
          
          <div className="space-y-1 px-2">
            {localAgents.map(agent => {
              const Icon = iconMap[agent.icon] || Terminal;
              const isSelected = selectedAgentId === agent.id && !searchQuery;
              return (
                <button
                  key={agent.id}
                  onClick={() => {
                    setSelectedAgentId(agent.id);
                    setSearchQuery('');
                  }}
                  className={`w-full flex items-center px-3 py-2 text-sm rounded-md transition-all duration-200 group
                    ${isSelected 
                      ? 'bg-blue-600/10 text-blue-400 font-medium' 
                      : 'text-gray-400 hover:bg-gray-800 hover:text-gray-200'}`}
                >
                  <Icon className={`w-4 h-4 mr-3 ${isSelected ? 'text-blue-400' : 'text-gray-500 group-hover:text-gray-300'}`} />
                  <span className="flex-1 text-left truncate">{agent.name}</span>
                  {agent.status === 'installed' ? (
                    <span className={`text-[10px] px-1.5 py-0.5 rounded-full border 
                      ${isSelected ? 'border-blue-500/30 text-blue-400 bg-blue-500/10' : 'border-gray-700 text-gray-500 bg-gray-800'}`}>
                      {agent.version}
                    </span>
                  ) : (
                    <span className="text-[10px] px-1.5 py-0.5 border border-red-500/30 text-red-400 bg-red-500/10 rounded-full">
                      Missing
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <div className="p-4 border-t border-gray-800">
          <div className="flex items-center text-xs text-gray-500">
            <div className="w-2 h-2 rounded-full bg-emerald-500 mr-2"></div>
            Daemon Active
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0 bg-gradient-to-br from-gray-900 to-gray-950">
        <header className="h-14 border-b border-gray-800 flex items-center px-6 shrink-0 relative z-20">
          <SearchBar searchQuery={searchQuery} setSearchQuery={setSearchQuery} />
        </header>

        <main className="flex-1 overflow-y-auto p-6 relative">
          <div className="max-w-4xl mx-auto">
            
            <div className="mb-8">
              <h1 className="text-2xl font-semibold text-gray-100 flex items-center">
                {searchQuery ? (
                  <>Search Results <span className="text-gray-500 text-lg ml-2 font-normal">"{searchQuery}"</span></>
                ) : (
                  <>
                    {mockAgents.find(a => a.id === selectedAgentId)?.name} Sessions
                  </>
                )}
              </h1>
              <p className="text-sm text-gray-400 mt-1">
                {searchQuery 
                  ? `Found ${filteredSessions.length} sessions across all environments.`
                  : `Select a past session to continue your work context or start a new one.`}
              </p>
            </div>

            <div className="grid grid-cols-1 gap-3">
              {filteredSessions.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-gray-800 rounded-xl">
                  <Command className="w-8 h-8 text-gray-600 mx-auto mb-3" />
                  <h3 className="text-gray-400 font-medium">No sessions found</h3>
                  <p className="text-sm text-gray-500 mt-1">Try a different search term or check local CLI paths.</p>
                </div>
              ) : (
                filteredSessions.map((session, idx) => {
                  const agent = mockAgents.find(a => a.id === session.agentId);
                  const Icon = iconMap[agent?.icon || 'Terminal'] || Terminal;
                  
                  return (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: idx * 0.05 }}
                      key={session.id}
                      onClick={() => setActiveSession(session)}
                      className="group bg-gray-800/40 hover:bg-gray-800/80 border border-gray-800 hover:border-gray-700 rounded-xl p-4 cursor-pointer transition-all duration-200"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex items-start space-x-4">
                          <div className="mt-1 p-2 bg-gray-900 rounded-lg border border-gray-800 group-hover:border-blue-500/30 transition-colors">
                            <Icon className="w-5 h-5 text-gray-400 group-hover:text-blue-400 transition-colors" />
                          </div>
                          <div>
                            <h3 className="text-gray-200 font-medium text-base group-hover:text-blue-400 transition-colors">
                              {session.title}
                            </h3>
                            <div className="flex items-center text-sm text-gray-500 mt-1.5 space-x-4">
                              <span className="flex items-center">
                                <Folder className="w-3.5 h-3.5 mr-1" />
                                {session.workspace}
                              </span>
                              <span className="flex items-center text-xs px-2 py-0.5 bg-gray-900 rounded-md border border-gray-800">
                                {agent?.name}
                              </span>
                            </div>
                          </div>
                        </div>
                        <div className="flex flex-col items-end space-y-2">
                          <span className="flex items-center text-xs text-gray-500">
                            <Clock className="w-3.5 h-3.5 mr-1" />
                            {session.lastActive}
                          </span>
                          <div className="flex flex-wrap justify-end gap-1.5">
                            {session.tags.map(tag => (
                              <span key={tag} className="text-[10px] text-gray-400 bg-gray-900 px-1.5 py-0.5 rounded flex items-center border border-gray-800">
                                <Tag className="w-2.5 h-2.5 mr-1" />
                                {tag}
                              </span>
                            ))}
                          </div>
                        </div>
                      </div>
                    </motion.div>
                  );
                })
              )}
            </div>
            
            {!searchQuery && (
              <motion.button 
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.3 }}
                onClick={() => setIsCreatingSession(true)}
                className="mt-6 w-full py-3 border border-dashed border-gray-700 hover:border-blue-500/50 hover:bg-blue-500/5 rounded-xl text-gray-400 hover:text-blue-400 transition-all flex items-center justify-center font-medium text-sm"
              >
                <PlusIcon className="w-4 h-4 mr-2" />
                Initialize New {mockAgents.find(a => a.id === selectedAgentId)?.name} Session
              </motion.button>
            )}

          </div>
        </main>
      </div>

      {/* Active Session Detail Overlay */}
      <AnimatePresence>
        {isCreatingSession && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6"
            onClick={() => setIsCreatingSession(false)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
              className="bg-gray-900 border border-gray-700 shadow-2xl rounded-2xl w-full max-w-2xl overflow-hidden flex flex-col"
            >
              <div className="px-6 py-5 border-b border-gray-800 flex items-start justify-between bg-gray-800/30">
                <div>
                  <h2 className="text-xl font-semibold text-gray-100 flex items-center">
                    <PlusIcon className="w-5 h-5 mr-2 text-blue-400" />
                    New {mockAgents.find(a => a.id === selectedAgentId)?.name} Session
                  </h2>
                  <p className="text-sm text-gray-500 mt-1 flex items-center">
                    Initialize a fresh context for your code agent.
                  </p>
                </div>
                <button 
                  onClick={() => setIsCreatingSession(false)}
                  className="p-1 text-gray-500 hover:bg-gray-800 hover:text-gray-300 rounded"
                >
                  <XCircle className="w-6 h-6" />
                </button>
              </div>
              
              <div className="p-6 flex-1 bg-gradient-to-b from-gray-900 to-gray-950 space-y-5">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Project Workspace</label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <Folder className="h-4 w-4 text-gray-500" />
                    </div>
                    <input
                      type="text"
                      value={newSessionMeta.workspace}
                      onChange={e => setNewSessionMeta({...newSessionMeta, workspace: e.target.value})}
                      className="block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg leading-5 bg-gray-800/50 text-gray-200 placeholder-gray-500 focus:outline-none focus:bg-gray-900 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm transition-all"
                      placeholder="e.g. ~/projects/my-new-app"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Session Title</label>
                  <input
                    type="text"
                    value={newSessionMeta.title}
                    onChange={e => setNewSessionMeta({...newSessionMeta, title: e.target.value})}
                    className="block w-full px-3 py-2 border border-gray-700 rounded-lg leading-5 bg-gray-800/50 text-gray-200 placeholder-gray-500 focus:outline-none focus:bg-gray-900 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm transition-all"
                    placeholder="e.g. initial setup"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Initial Prompt (Optional)</label>
                  <textarea
                    rows={3}
                    className="block w-full px-3 py-2 border border-gray-700 rounded-lg leading-5 bg-gray-800/50 text-gray-200 placeholder-gray-500 focus:outline-none focus:bg-gray-900 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm transition-all resize-none"
                    placeholder="e.g. Scrape the provided URL and build a summary dashboard..."
                  ></textarea>
                </div>

                <div className="bg-gray-800/30 p-4 rounded-xl border border-gray-800">
                  <span className="block text-gray-500 text-sm mb-3">Available Agent Features</span>
                  <div className="grid grid-cols-2 gap-3">
                    {mockAgents.find(a => a.id === selectedAgentId)?.features?.map(feature => (
                      <div key={feature} className="flex items-center space-x-2 text-sm text-gray-300">
                        <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                        <span>{feature}</span>
                      </div>
                    )) || (
                      <div className="text-gray-500 text-sm">No special features listed.</div>
                    )}
                  </div>
                </div>

                <div className="bg-black/50 border border-gray-800 rounded-xl p-4 font-mono text-xs overflow-x-auto">
                  <div className="flex items-center text-gray-500 mb-2 font-sans text-xs uppercase tracking-wider">
                    <Terminal className="w-3 h-3 mr-1" /> Startup Command Preview
                  </div>
                  <div className="text-emerald-400 flex">
                    <span className="text-gray-600 mr-2">$</span>
                    <span>
                      cd {newSessionMeta.workspace || '~/projects/new-project'} && {mockAgents.find(a => a.id === selectedAgentId)?.cmd} --new
                    </span>
                  </div>
                </div>
              </div>

              <div className="px-6 py-4 border-t border-gray-800 bg-gray-900/80 flex justify-end space-x-3">
                <button 
                  onClick={() => setIsCreatingSession(false)}
                  className="px-4 py-2 rounded-lg text-sm font-medium text-gray-400 hover:text-gray-200 transition-colors"
                >
                  Cancel
                </button>
                <button 
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-sm font-medium transition-colors flex items-center"
                  onClick={() => {
                    if (selectedAgentId && newSessionMeta.title.trim() && newSessionMeta.workspace.trim()) {
                      const newSession: Session = {
                        id: `s-new-${Date.now()}`,
                        agentId: selectedAgentId,
                        title: newSessionMeta.title.trim(),
                        workspace: newSessionMeta.workspace.trim(),
                        lastActive: 'Just now',
                        historyCount: 1,
                        tags: ['new']
                      };
                      setSessions([newSession, ...sessions]);
                      setNewSessionMeta({ workspace: '~/projects/new-project', title: '' });
                      setIsCreatingSession(false);
                      // Set newly created as active immediately
                      setActiveSession(newSession);
                    } else {
                      alert('Please fill out workspace and session title.');
                    }
                  }}
                >
                  <Play className="w-4 h-4 mr-2" />
                  Initialize Context
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}

        {activeSession && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6"
            onClick={() => setActiveSession(null)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
              className="bg-gray-900 border border-gray-700 shadow-2xl rounded-2xl w-full max-w-2xl overflow-hidden flex flex-col"
            >
              <div className="px-6 py-5 border-b border-gray-800 flex items-start justify-between bg-gray-800/30">
                <div>
                  <h2 className="text-xl font-semibold text-gray-100">{activeSession.title}</h2>
                  <p className="text-sm text-gray-500 mt-1 flex items-center">
                    <Folder className="w-4 h-4 mr-1.5" />
                    {activeSession.workspace}
                  </p>
                </div>
                <button 
                  onClick={() => setActiveSession(null)}
                  className="p-1 text-gray-500 hover:bg-gray-800 hover:text-gray-300 rounded"
                >
                  <XCircle className="w-6 h-6" />
                </button>
              </div>
              
              <div className="p-6 flex-1 bg-gradient-to-b from-gray-900 to-gray-950">
                <div className="grid grid-cols-2 gap-4 mb-6 text-sm">
                  <div className="bg-gray-800/50 p-4 rounded-xl border border-gray-800">
                    <span className="block text-gray-500 mb-1">Agent Environment</span>
                    <div className="flex items-center text-gray-200 font-medium">
                      {mockAgents.find(a => a.id === activeSession.agentId)?.name || 'Unknown'} 
                      <span className="ml-2 px-1.5 py-0.5 text-[10px] bg-gray-800 text-gray-400 border border-gray-700 rounded-full">
                        {mockAgents.find(a => a.id === activeSession.agentId)?.version}
                      </span>
                    </div>
                  </div>
                  <div className="bg-gray-800/50 p-4 rounded-xl border border-gray-800">
                    <span className="block text-gray-500 mb-1">State Details</span>
                    <div className="text-gray-200">
                      {activeSession.historyCount} messages in context history
                    </div>
                  </div>
                </div>

                <div className="bg-black/50 border border-gray-800 rounded-xl p-4 font-mono text-xs overflow-x-auto">
                  <div className="flex items-center text-gray-500 mb-2 font-sans text-xs uppercase tracking-wider">
                    <Terminal className="w-3 h-3 mr-1" /> Command Preview
                  </div>
                  <div className="text-emerald-400 flex">
                    <span className="text-gray-600 mr-2">$</span>
                    <span>
                      cd {activeSession.workspace} && {mockAgents.find(a => a.id === activeSession.agentId)?.cmd} --resume {activeSession.id}
                    </span>
                  </div>
                </div>
              </div>

              <div className="px-6 py-4 border-t border-gray-800 bg-gray-900/80 flex justify-end space-x-3">
                <button 
                  onClick={() => setActiveSession(null)}
                  className="px-4 py-2 rounded-lg text-sm font-medium text-gray-400 hover:text-gray-200 transition-colors"
                >
                  Cancel
                </button>
                <button 
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-sm font-medium transition-colors flex items-center"
                  onClick={() => {
                    // Mock continuing the session
                    alert(`Starting session context: ${activeSession.title}`);
                    setActiveSession(null);
                  }}
                >
                  <Play className="w-4 h-4 mr-2" />
                  Continue Session
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  );
}

function PlusIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      {...props}
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 12h14" />
      <path d="M12 5v14" />
    </svg>
  );
}

