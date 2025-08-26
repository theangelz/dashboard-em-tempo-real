"use client";

import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { 
  Activity, 
  AlertTriangle, 
  Clock, 
  Database, 
  Globe, 
  Server, 
  TrendingUp,
  Users,
  Wifi,
  HardDrive
} from "lucide-react";
import Link from "next/link";

export default function DashboardPage() {
  const [metrics, setMetrics] = useState({
    eventsPerMinute: 1247,
    totalEvents: 15678432,
    ingestDelay: 2.3,
    storageUsed: 67,
    activeConnections: 8934,
    parseErrors: 12
  });

  const [topIPs, setTopIPs] = useState([
    
    { ip: "177.45.123.45", events: 15234, percentage: 12.4 },
    { ip: "177.45.123.46", events: 12890, percentage: 10.5 },
    { ip: "177.45.123.47", events: 11567, percentage: 9.4 },
    { ip: "177.45.123.48", events: 9876, percentage: 8.0 },
    { ip: "177.45.123.49", events: 8765, percentage: 7.1 }
  ]);

  const [topPorts, setTopPorts] = useState([
    { port: 80, protocol: "HTTP", events: 45678, percentage: 23.4 },
    { port: 443, protocol: "HTTPS", events: 38901, percentage: 19.9 },
    { port: 53, protocol: "DNS", events: 12345, percentage: 6.3 },
    { port: 25, protocol: "SMTP", events: 8901, percentage: 4.6 },
    { port: 21, protocol: "FTP", events: 5678, percentage: 2.9 }
  ]);

  const [recentErrors, setRecentErrors] = useState([
    { time: "14:32:15", message: "Parse failure: invalid timestamp format", source: "192.168.1.100" },
    { time: "14:28:42", message: "Missing destination port in log entry", source: "192.168.1.101" },
    { time: "14:25:18", message: "Unknown protocol identifier: 'xyz'", source: "192.168.1.102" }
  ]);

  // Simular atualizações em tempo real
  useEffect(() => {
    const interval = setInterval(() => {
      setMetrics(prev => ({
        ...prev,
        eventsPerMinute: prev.eventsPerMinute + Math.floor(Math.random() * 100) - 50,
        totalEvents: prev.totalEvents + Math.floor(Math.random() * 1000),
        ingestDelay: Math.max(0.1, prev.ingestDelay + (Math.random() - 0.5) * 0.5),
        activeConnections: prev.activeConnections + Math.floor(Math.random() * 200) - 100
      }));
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (delay: number) => {
    if (delay < 2) return "text-green-600";
    if (delay < 5) return "text-yellow-600";
    return "text-red-600";
  };

  const getStatusBadge = (delay: number) => {
    if (delay < 2) return <Badge className="bg-green-100 text-green-800">Excelente</Badge>;
    if (delay < 5) return <Badge className="bg-yellow-100 text-yellow-800">Atenção</Badge>;
    return <Badge className="bg-red-100 text-red-800">Crítico</Badge>;
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-2xl font-bold">Dashboard</h1>
              <p className="text-gray-600">Monitoramento em tempo real dos logs NAT/CGNAT</p>
            </div>
            <div className="flex space-x-4">
              <Link href="/search">
                <Button>Buscar Logs</Button>
              </Link>
              <Link href="/reports">
                <Button variant="outline">Relatórios</Button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Métricas Principais */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Eventos/Minuto</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{metrics.eventsPerMinute.toLocaleString()}</div>
              <p className="text-xs text-muted-foreground">
                <TrendingUp className="inline h-3 w-3 mr-1" />
                +12% desde ontem
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total de Eventos</CardTitle>
              <Database className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{metrics.totalEvents.toLocaleString()}</div>
              <p className="text-xs text-muted-foreground">
                Últimas 24 horas
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Atraso de Ingestão</CardTitle>
              <Clock className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className={`text-2xl font-bold ${getStatusColor(metrics.ingestDelay)}`}>
                {metrics.ingestDelay.toFixed(1)}s
              </div>
              <div className="mt-1">
                {getStatusBadge(metrics.ingestDelay)}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Armazenamento</CardTitle>
              <HardDrive className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{metrics.storageUsed}%</div>
              <Progress value={metrics.storageUsed} className="mt-2" />
              <p className="text-xs text-muted-foreground mt-1">
                2.1 TB de 3.2 TB utilizados
              </p>
            </CardContent>
          </Card>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          {/* Top IPs Públicos */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center">
                <Globe className="h-5 w-5 mr-2" />
                Top IPs Públicos
              </CardTitle>
              <CardDescription>
                IPs com maior volume de eventos nas últimas 24h
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {topIPs.map((item, index) => (
                  <div key={index} className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center text-sm font-medium text-blue-600">
                        {index + 1}
                      </div>
                      <div>
                        <div className="font-medium">{item.ip}</div>
                        <div className="text-sm text-gray-500">{item.events.toLocaleString()} eventos</div>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium">{item.percentage}%</div>
                      <Progress value={item.percentage} className="w-16 h-2" />
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Top Portas de Destino */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center">
                <Server className="h-5 w-5 mr-2" />
                Top Portas de Destino
              </CardTitle>
              <CardDescription>
                Portas mais acessadas nas últimas 24h
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {topPorts.map((item, index) => (
                  <div key={index} className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center text-sm font-medium text-green-600">
                        {index + 1}
                      </div>
                      <div>
                        <div className="font-medium">Porta {item.port}</div>
                        <div className="text-sm text-gray-500">{item.protocol} • {item.events.toLocaleString()} eventos</div>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium">{item.percentage}%</div>
                      <Progress value={item.percentage} className="w-16 h-2" />
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Status do Sistema */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center">
                <Wifi className="h-5 w-5 mr-2" />
                Status do Sistema
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm">Elasticsearch</span>
                <Badge className="bg-green-100 text-green-800">Online</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Logstash</span>
                <Badge className="bg-green-100 text-green-800">Online</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Kibana</span>
                <Badge className="bg-green-100 text-green-800">Online</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Backup</span>
                <Badge className="bg-green-100 text-green-800">OK</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Conexões Ativas</span>
                <span className="text-sm font-medium">{metrics.activeConnections}</span>
              </div>
            </CardContent>
          </Card>

          {/* Erros Recentes */}
          <Card className="lg:col-span-2">
            <CardHeader>
              <CardTitle className="flex items-center">
                <AlertTriangle className="h-5 w-5 mr-2" />
                Erros Recentes de Parse
              </CardTitle>
              <CardDescription>
                {metrics.parseErrors} erros nas últimas 24 horas
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {recentErrors.map((error, index) => (
                  <div key={index} className="flex items-start space-x-3 p-3 bg-red-50 rounded-lg">
                    <AlertTriangle className="h-4 w-4 text-red-500 mt-0.5" />
                    <div className="flex-1">
                      <div className="text-sm font-medium text-red-800">{error.message}</div>
                      <div className="text-xs text-red-600 mt-1">
                        {error.time} • Origem: {error.source}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              {recentErrors.length === 0 && (
                <div className="text-center py-8 text-gray-500">
                  <AlertTriangle className="h-8 w-8 mx-auto mb-2 opacity-50" />
                  <p>Nenhum erro de parse recente</p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}