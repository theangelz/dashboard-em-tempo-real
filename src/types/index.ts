export interface LogEvent {
  timestamp: string;
  sourceIp: string;
  sourcePort: number;
  natIp: string;
  natPort: number;
  destIp: string;
  destPort: number;
  protocol: 'TCP' | 'UDP';
  sessionId?: string;
  user?: string;
  observerHostname?: string;
  observerVendor?: string;
  observerProduct?: string;
}

export interface SearchParams {
  publicIp?: string;
  publicPort?: string;
  privateIp?: string;
  startDate?: string;
  startTime?: string;
  endDate?: string;
  endTime?: string;
  timezone: string;
  limit?: number;
  offset?: number;
}

export interface SearchResponse {
  events: LogEvent[];
  total: number;
  took: number;
  page: number;
  pageSize: number;
}

export interface User {
  id: string;
  name: string;
  email: string;
  company: string;
  role: 'admin' | 'operacao' | 'juridico';
  createdAt: string;
  lastLogin?: string;
}

export interface SystemMetrics {
  eventsPerMinute: number;
  totalEvents: number;
  ingestDelay: number;
  storageUsed: number;
  activeConnections: number;
  parseErrors: number;
  elasticsearchStatus: 'online' | 'offline' | 'degraded';
  logstashStatus: 'online' | 'offline' | 'degraded';
  kibanaStatus: 'online' | 'offline' | 'degraded';
}

export interface TopItem {
  value: string;
  count: number;
  percentage: number;
}

export interface ReportRequest {
  searchParams: SearchParams;
  format: '
' | 'csv';
  maxRows?: number;
  includeHash?: boolean;
}

export interface AuditLog {
  id: string;
  userId: string;
  userName: string;
  action: 'login' | 'logout' | 'search' | 'export_pdf' | 'export_csv';
  details: Record<string, any>;
  ipAddress: string;
  userAgent: string;
  timestamp: string;
}