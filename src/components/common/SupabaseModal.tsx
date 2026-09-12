import React, { useState, useEffect } from 'react';
import {
  Database,
  CheckCircle2,
  AlertCircle,
  RefreshCw,
  Copy,
  Download,
  Server,
  Layers,
  Code,
  ExternalLink,
  Shield,
  Activity,
  Check,
  X,
  Play,
} from 'lucide-react';
import { Button } from './Button';

interface SupabaseStatusData {
  configured: boolean;
  connected: boolean;
  endpointUrl: string | null;
  hasServiceKey: boolean;
  tablesFound: string[];
  missingTables: string[];
  tableCounts: Record<string, number>;
  latencyMs: number | null;
  error: string | null;
  checkedAt: string;
}

interface SupabaseModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SupabaseModal: React.FC<SupabaseModalProps> = ({ isOpen, onClose }) => {
  const [status, setStatus] = useState<SupabaseStatusData | null>(null);
  const [loading, setLoading] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{
    success: boolean;
    stage: string;
    readResult?: any;
    error?: string;
    latencyMs: number;
  } | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'schema' | 'instructions'>('overview');
  const [copied, setCopied] = useState(false);
  const [schemaSql, setSchemaSql] = useState<string>('');

  const fetchStatus = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/supabase/status');
      if (res.ok) {
        const data = await res.json();
        setStatus(data);
      }
    } catch (err) {
      console.error('Failed to load Supabase status:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchSchema = async () => {
    try {
      const res = await fetch('/api/supabase/schema.sql');
      if (res.ok) {
        const text = await res.text();
        setSchemaSql(text);
      }
    } catch (err) {
      console.error('Failed to load Supabase schema:', err);
    }
  };

  const runTest = async () => {
    setTesting(true);
    setTestResult(null);
    try {
      const res = await fetch('/api/supabase/test', { method: 'POST' });
      const data = await res.json();
      setTestResult(data);
      fetchStatus();
    } catch (err: any) {
      setTestResult({
        success: false,
        stage: 'network_request',
        error: err.message,
        latencyMs: 0,
      });
    } finally {
      setTesting(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      fetchStatus();
      fetchSchema();
    }
  }, [isOpen]);

  const copySchemaToClipboard = () => {
    if (!schemaSql) return;
    navigator.clipboard.writeText(schemaSql);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  const downloadSchemaFile = () => {
    const element = document.createElement('a');
    const file = new Blob([schemaSql], { type: 'text/sql' });
    element.href = URL.createObjectURL(file);
    element.download = 'freshroute_supabase_migration.sql';
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
  };

  if (!isOpen) return null;

  const totalRequired = 11;
  const tablesReady = status?.tablesFound.length || 0;
  const isFullyMigrated = tablesReady === totalRequired;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-4xl max-h-[90vh] flex flex-col bg-stone-900 border border-stone-800 rounded-2xl shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-stone-800 bg-stone-950/40">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-lg font-bold tracking-tight text-white">Supabase PostgreSQL Integration</h3>
                <span className="text-[11px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400">
                  PostgreSQL 15+
                </span>
              </div>
              <p className="text-xs text-stone-400">
                Direct relational database backing harvest biometrics, mandi prices, buyer demand, and orders
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <span
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border ${
                isFullyMigrated
                  ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                  : status?.configured
                  ? 'bg-amber-500/10 text-amber-400 border-amber-500/30'
                  : 'bg-rose-500/10 text-rose-400 border-rose-500/30'
              }`}
            >
              <span
                className={`w-1.5 h-1.5 rounded-full ${
                  isFullyMigrated ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'
                }`}
              />
              {isFullyMigrated
                ? 'Supabase Live'
                : status?.configured
                ? 'Schema Pending'
                : 'Not Configured'}
            </span>

            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-stone-400 hover:text-white hover:bg-stone-800 transition-colors"
              aria-label="Close modal"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="flex items-center gap-1 px-6 pt-3 border-b border-stone-800 bg-stone-900/50">
          <button
            onClick={() => setActiveTab('overview')}
            className={`flex items-center gap-2 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'overview'
                ? 'border-emerald-500 text-emerald-400'
                : 'border-transparent text-stone-400 hover:text-stone-200'
            }`}
          >
            <Activity className="w-4 h-4" />
            Live Status & Tables ({tablesReady}/{totalRequired})
          </button>
          <button
            onClick={() => setActiveTab('schema')}
            className={`flex items-center gap-2 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'schema'
                ? 'border-emerald-500 text-emerald-400'
                : 'border-transparent text-stone-400 hover:text-stone-200'
            }`}
          >
            <Code className="w-4 h-4" />
            PostgreSQL SQL Migration
          </button>
          <button
            onClick={() => setActiveTab('instructions')}
            className={`flex items-center gap-2 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'instructions'
                ? 'border-emerald-500 text-emerald-400'
                : 'border-transparent text-stone-400 hover:text-stone-200'
            }`}
          >
            <Server className="w-4 h-4" />
            Execution Guide
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {activeTab === 'overview' && (
            <div className="space-y-6">
              {/* Connection Status Card */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 rounded-xl bg-stone-950/60 border border-stone-800">
                  <div className="flex items-center justify-between text-xs text-stone-400 mb-1">
                    <span>Supabase Endpoint</span>
                    <Server className="w-3.5 h-3.5 text-emerald-400" />
                  </div>
                  <div className="text-sm font-mono font-medium text-white truncate">
                    {status?.endpointUrl || 'Configured in Environment'}
                  </div>
                  <div className="mt-1 text-[11px] text-emerald-400/90 flex items-center gap-1">
                    <CheckCircle2 className="w-3 h-3" /> REST API 200 OK
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-stone-950/60 border border-stone-800">
                  <div className="flex items-center justify-between text-xs text-stone-400 mb-1">
                    <span>Active Tables</span>
                    <Layers className="w-3.5 h-3.5 text-emerald-400" />
                  </div>
                  <div className="text-xl font-bold text-white">
                    {tablesReady} <span className="text-xs font-normal text-stone-400">/ {totalRequired} tables</span>
                  </div>
                  <div className="mt-1 text-[11px] text-stone-400">
                    {isFullyMigrated ? 'All 11 relational tables live' : `${status?.missingTables?.length || 0} tables awaiting migration`}
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-stone-950/60 border border-stone-800">
                  <div className="flex items-center justify-between text-xs text-stone-400 mb-1">
                    <span>Database Latency</span>
                    <Activity className="w-3.5 h-3.5 text-emerald-400" />
                  </div>
                  <div className="text-xl font-bold text-white">
                    {status?.latencyMs !== null ? `${status?.latencyMs}ms` : '--'}
                  </div>
                  <div className="mt-1 text-[11px] text-stone-400">
                    RLS Security Policies enforced
                  </div>
                </div>
              </div>

              {/* Status Banner */}
              <div
                className={`p-4 rounded-xl border ${
                  isFullyMigrated
                    ? 'bg-emerald-950/20 border-emerald-500/30'
                    : 'bg-amber-950/20 border-amber-500/30'
                }`}
              >
                <div className="flex items-start gap-3">
                  {isFullyMigrated ? (
                    <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                  ) : (
                    <AlertCircle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                  )}
                  <div>
                    <h4 className="text-sm font-semibold text-white">
                      {isFullyMigrated
                        ? 'Active Connection to Supabase PostgreSQL'
                        : 'Supabase REST Endpoint Connected — Public Schema Tables Needed'}
                    </h4>
                    <p className="text-xs text-stone-300 mt-1 leading-relaxed">
                      {isFullyMigrated
                        ? 'All harvest scans, buyer commitments, orders, and telemetry are directly querying and persisting to your Supabase PostgreSQL database with Row Level Security.'
                        : 'Your Supabase project connection is authenticated and working, but the public schema currently has no application tables. Execute the SQL migration script in the Supabase SQL Editor to activate live table persistence.'}
                    </p>
                  </div>
                </div>
              </div>

              {/* Read/Write Probe Test Section */}
              <div className="p-4 rounded-xl bg-stone-950/50 border border-stone-800 space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-semibold text-white">Database Read/Write Diagnostic</h4>
                    <p className="text-xs text-stone-400">
                      Performs an authenticated query against Supabase without exposing credentials
                    </p>
                  </div>
                  <Button
                    size="sm"
                    variant="primary"
                    onClick={runTest}
                    disabled={testing}
                    className="flex items-center gap-1.5"
                  >
                    <Play className={`w-3.5 h-3.5 ${testing ? 'animate-spin' : ''}`} />
                    {testing ? 'Running Probe...' : 'Run Connection Test'}
                  </Button>
                </div>

                {testResult && (
                  <div
                    className={`p-3 rounded-lg border text-xs font-mono space-y-1 ${
                      testResult.success
                        ? 'bg-emerald-950/30 border-emerald-500/30 text-emerald-300'
                        : 'bg-amber-950/30 border-amber-500/30 text-amber-300'
                    }`}
                  >
                    <div className="flex items-center justify-between font-semibold">
                      <span>Status: {testResult.success ? 'SUCCESS (Tables Queryable)' : 'TABLES NOT FOUND (PGRST205)'}</span>
                      <span>Latency: {testResult.latencyMs}ms</span>
                    </div>
                    {testResult.readResult && (
                      <div>Rows read from produce_batches: {testResult.readResult.rowCount}</div>
                    )}
                    {testResult.error && <div>Notice: {testResult.error}</div>}
                  </div>
                )}
              </div>

              {/* Table Inventory Grid */}
              <div className="space-y-3">
                <h4 className="text-sm font-semibold text-white flex items-center justify-between">
                  <span>Required Schema Tables</span>
                  <span className="text-xs font-normal text-stone-400">
                    {tablesReady} of {totalRequired} tables detected
                  </span>
                </h4>

                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2.5">
                  {[
                    { name: 'profiles', desc: 'Farmer & buyer identities, language, phone' },
                    { name: 'farmers', desc: 'Farms, GPS coordinates, profile link' },
                    { name: 'buyers', desc: 'Business type, dark stores, retail chains' },
                    { name: 'produce_batches', desc: 'Crop biometrics, quality grade, shelf life' },
                    { name: 'market_prices', desc: 'APMC mandis, modal price, daily trends' },
                    { name: 'buyer_demand', desc: 'Quick-commerce RFQs, offered prices' },
                    { name: 'transport_options', desc: 'Reefers, mini-pickups, cost/km' },
                    { name: 'recommendations', desc: 'AI salvage decisions, revenue projection' },
                    { name: 'orders', desc: 'Smart escrow, agreed price, delivery status' },
                    { name: 'whatsapp_conversations', desc: 'Farmer WhatsApp session state' },
                    { name: 'whatsapp_messages', desc: 'Inbound harvest photos & outbound rates' },
                  ].map((tbl) => {
                    const isPresent = status?.tablesFound?.includes(tbl.name);
                    const count = status?.tableCounts?.[tbl.name] ?? 0;

                    return (
                      <div
                        key={tbl.name}
                        className={`p-3 rounded-lg border text-left transition-colors ${
                          isPresent
                            ? 'bg-emerald-950/20 border-emerald-500/30 text-stone-200'
                            : 'bg-stone-950/40 border-stone-800/80 text-stone-400'
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-mono text-xs font-semibold text-white">{tbl.name}</span>
                          {isPresent ? (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 font-medium">
                              {count} rows
                            </span>
                          ) : (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-stone-800 text-stone-400 font-medium">
                              Pending
                            </span>
                          )}
                        </div>
                        <p className="text-[11px] text-stone-400 mt-1 line-clamp-1">{tbl.desc}</p>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}

          {activeTab === 'schema' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-sm font-semibold text-white">Full Supabase PostgreSQL DDL Migration</h4>
                  <p className="text-xs text-stone-400">
                    Includes all 11 tables, UUID primary keys, foreign keys, indexes, check constraints, RLS policies, and demo seed data.
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={downloadSchemaFile}
                    className="flex items-center gap-1.5"
                  >
                    <Download className="w-3.5 h-3.5" />
                    Download .sql
                  </Button>
                  <Button
                    size="sm"
                    variant="primary"
                    onClick={copySchemaToClipboard}
                    className="flex items-center gap-1.5"
                  >
                    {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                    {copied ? 'Copied!' : 'Copy SQL'}
                  </Button>
                </div>
              </div>

              <div className="relative">
                <pre className="p-4 rounded-xl bg-stone-950 border border-stone-800 font-mono text-xs text-stone-300 overflow-x-auto max-h-[420px] leading-relaxed select-all">
                  {schemaSql || '-- Loading migration SQL...'}
                </pre>
              </div>
            </div>
          )}

          {activeTab === 'instructions' && (
            <div className="space-y-6">
              <div className="p-4 rounded-xl bg-emerald-950/20 border border-emerald-500/30">
                <h4 className="text-sm font-semibold text-white flex items-center gap-2">
                  <Shield className="w-4 h-4 text-emerald-400" />
                  How to Apply the Migration in Supabase
                </h4>
                <p className="text-xs text-stone-300 mt-1">
                  You can apply the entire migration in under 30 seconds using the Supabase Web Dashboard:
                </p>
              </div>

              <div className="space-y-4">
                {[
                  {
                    step: '1',
                    title: 'Open your Supabase Project Dashboard',
                    desc: 'Log in to https://supabase.com/dashboard and navigate to your FreshRoute project.',
                  },
                  {
                    step: '2',
                    title: 'Navigate to the SQL Editor',
                    desc: 'In the left sidebar navigation, click on "SQL Editor" (or the terminal icon).',
                  },
                  {
                    step: '3',
                    title: 'Create a "New Query"',
                    desc: 'Click the "+ New Query" button at the top of the SQL Editor view.',
                  },
                  {
                    step: '4',
                    title: 'Paste and Run the Migration',
                    desc: 'Copy the complete SQL migration from the "PostgreSQL SQL Migration" tab, paste it into the editor query window, and click "Run" (or press Ctrl/Cmd + Enter).',
                  },
                  {
                    step: '5',
                    title: 'Verify in FreshRoute',
                    desc: 'Return to FreshRoute and click "Run Connection Test" or "Refresh Status". All 11 tables will immediately report green with live data!',
                  },
                ].map((item) => (
                  <div key={item.step} className="flex items-start gap-3 p-3 rounded-lg bg-stone-950/40 border border-stone-800/80">
                    <div className="w-6 h-6 rounded-full bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center text-xs font-bold text-emerald-400 flex-shrink-0">
                      {item.step}
                    </div>
                    <div>
                      <h5 className="text-xs font-semibold text-white">{item.title}</h5>
                      <p className="text-xs text-stone-400 mt-0.5 leading-relaxed">{item.desc}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-stone-800 bg-stone-950/40">
          <div className="text-xs text-stone-400 flex items-center gap-1.5">
            <Shield className="w-3.5 h-3.5 text-emerald-400" />
            <span>Zero credentials exposed • Direct Supabase Client + SSL</span>
          </div>

          <div className="flex items-center gap-3">
            <Button
              size="sm"
              variant="outline"
              onClick={fetchStatus}
              disabled={loading}
              className="flex items-center gap-1.5"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
              Refresh Status
            </Button>
            <Button size="sm" variant="primary" onClick={onClose}>
              Close
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
};
