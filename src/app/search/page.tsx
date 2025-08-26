"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { 
  Search, 
  Download, 
  FileText, 
  Copy, 
  Calendar,
  Clock,
  Globe,
  Server,
  Filter
} from "lucide-react";
import { toast } from "sonner";

export default function SearchPage() {
  const [searchParams, setSearchParams] = useState({
    publicIp: "",
    publicPort: "",
    privateIp: "",
    startDate: "",
    startTime: "",
    endDate: "",
    endTime: "",
    timezone: "America/Sao_Paulo"
  });

  const [results, setResults] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [totalResults, setTotalResults] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [hasSearched, setHasSearched] = useState(false);

  // Dados de exemplo para demonstração
  const sampleResults = [
    {
      timestamp: "2024-01-15T14:32:15.123Z",
      sourceIp: "100.64.1.45",
      sourcePort: 54321,
      natIp: "177.45.123.45",
      natPort: 12345,
      destIp: "8.8.8.8",
      destPort: 53,
      protocol: "UDP",
      sessionId: "sess_abc123",
      user: "user@provedor.com"
    },
    {
      timestamp: "2024-01-15T14:32:14.987Z",
      sourceIp: "100.64.1.45",
      sourcePort: 54320,
      natIp: "177.45.123.45",
      natPort: 12344,
      destIp: "1.1.1.1",
      destPort: 53,
      protocol: "UDP",
      sessionId: "sess_abc124",
      user: "user@provedor.com"
    }
  ];

  const handleInputChange = (field: string, value: string) => {
    setSearchParams(prev => ({ ...prev, [field]: value }));
  };

  const handleSearch = async () => {
    setIsLoading(true);
    setHasSearched(true);
    
    try {
      // TODO: Implementar busca real no Elasticsearch
      console.log("Search params:", searchParams);
      
      // Simulação de busca
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Se há parâmetros de busca, mostrar resultados de exemplo
      if (searchParams.publicIp || searchParams.privateIp || searchParams.publicPort) {
        setResults(sampleResults);
        setTotalResults(sampleResults.length);
      } else {
        setResults([]);
        setTotalResults(0);
      }
      
      toast.success(`Busca concluída. ${sampleResults.length} resultados encontrados.`);
    } catch (error) {
      toast.error("Erro ao realizar busca. Tente novamente.");
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopyRow = (row: any) => {
    const text = `${row.timestamp} | ${row.sourceIp}:${row.sourcePort} -> ${row.natIp}:${row.natPort} -> ${row.destIp}:${row.destPort} | ${row.protocol}`;
    navigator.clipboard.writeText(text);
    toast.success("Linha copiada para a área de transferência");
  };

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleString('pt-BR', {
      timeZone: searchParams.timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const getProtocolBadge = (protocol: string) => {
    const color = protocol === 'TCP' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800';
    return <Badge className={color}>{protocol}</Badge>;
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-2xl font-bold">Busca Avançada</h1>
              <p className="text-gray-600">Pesquise logs NAT/CGNAT por IP, porta ou intervalo de tempo</p>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Formulário de Busca */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle className="flex items-center">
              <Filter className="h-5 w-5 mr-2" />
              Filtros de Busca
            </CardTitle>
            <CardDescription>
              Preencha os campos para filtrar os logs. Pelo menos um campo deve ser preenchido.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {/* IP Público */}
              <div className="space-y-2">
                <Label htmlFor="publicIp" className="flex items-center">
                  <Globe className="h-4 w-4 mr-1" />
                  IP Público
                </Label>
                <Input
                  id="publicIp"
                  placeholder="177.45.123.45"
                  value={searchParams.publicIp}
                  onChange={(e) => handleInputChange("publicIp", e.target.value)}
                />
              </div>

              {/* Porta Pública */}
              <div className="space-y-2">
                <Label htmlFor="publicPort" className="flex items-center">
                  <Server className="h-4 w-4 mr-1" />
                  Porta Pública
                </Label>
                <Input
                  id="publicPort"
                  placeholder="12345"
                  type="number"
                  value={searchParams.publicPort}
                  onChange={(e) => handleInputChange("publicPort", e.target.value)}
                />
              </div>

              {/* IP Privado */}
              <div className="space-y-2">
                <Label htmlFor="privateIp">IP Privado</Label>
                <Input
                  id="privateIp"
                  placeholder="100.64.1.45"
                  value={searchParams.privateIp}
                  onChange={(e) => handleInputChange("privateIp", e.target.value)}
                />
              </div>

              {/* Data Início */}
              <div className="space-y-2">
                <Label htmlFor="startDate" className="flex items-center">
                  <Calendar className="h-4 w-4 mr-1" />
                  Data Início
                </Label>
                <Input
                  id="startDate"
                  type="date"
                  value={searchParams.startDate}
                  onChange={(e) => handleInputChange("startDate", e.target.value)}
                />
              </div>

              {/* Hora Início */}
              <div className="space-y-2">
                <Label htmlFor="startTime" className="flex items-center">
                  <Clock className="h-4 w-4 mr-1" />
                  Hora Início
                </Label>
                <Input
                  id="startTime"
                  type="time"
                  step="1"
                  value={searchParams.startTime}
                  onChange={(e) => handleInputChange("startTime", e.target.value)}
                />
              </div>

              {/* Fuso Horário */}
              <div className="space-y-2">
                <Label htmlFor="timezone">Fuso Horário</Label>
                <Select value={searchParams.timezone} onValueChange={(value) => handleInputChange("timezone", value)}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="America/Sao_Paulo">UTC-3 (São Paulo)</SelectItem>
                    <SelectItem value="UTC">UTC</SelectItem>
                    <SelectItem value="America/Manaus">UTC-4 (Manaus)</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {/* Data Fim */}
              <div className="space-y-2">
                <Label htmlFor="endDate">Data Fim</Label>
                <Input
                  id="endDate"
                  type="date"
                  value={searchParams.endDate}
                  onChange={(e) => handleInputChange("endDate", e.target.value)}
                />
              </div>

              {/* Hora Fim */}
              <div className="space-y-2">
                <Label htmlFor="endTime">Hora Fim</Label>
                <Input
                  id="endTime"
                  type="time"
                  step="1"
                  value={searchParams.endTime}
                  onChange={(e) => handleInputChange("endTime", e.target.value)}
                />
              </div>
            </div>

            <div className="flex justify-between items-center mt-6">
              <Button
                onClick={handleSearch}
                disabled={isLoading}
                className="flex items-center"
              >
                <Search className="h-4 w-4 mr-2" />
                {isLoading ? "Buscando..." : "Buscar"}
              </Button>

              <div className="flex space-x-2">
                <Button variant="outline" disabled={results.length === 0}>
                  <FileText className="h-4 w-4 mr-2" />
                  Gerar PDF
                </Button>
                <Button variant="outline" disabled={results.length === 0}>
                  <Download className="h-4 w-4 mr-2" />
                  Exportar CSV
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Resultados */}
        {hasSearched && (
          <Card>
            <CardHeader>
              <CardTitle>Resultados da Busca</CardTitle>
              <CardDescription>
                {totalResults > 0 
                  ? `${totalResults} resultado(s) encontrado(s)`
                  : "Nenhum resultado encontrado"
                }
              </CardDescription>
            </CardHeader>
            <CardContent>
              {results.length > 0 ? (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Timestamp</TableHead>
                        <TableHead>IP Origem</TableHead>
                        <TableHead>Porta Origem</TableHead>
                        <TableHead>IP NAT</TableHead>
                        <TableHead>Porta NAT</TableHead>
                        <TableHead>IP Destino</TableHead>
                        <TableHead>Porta Destino</TableHead>
                        <TableHead>Protocolo</TableHead>
                        <TableHead>Usuário</TableHead>
                        <TableHead>Ações</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {results.map((row: any, index) => (
                        <TableRow key={index}>
                          <TableCell className="font-mono text-sm">
                            {formatTimestamp(row.timestamp)}
                          </TableCell>
                          <TableCell className="font-mono">{row.sourceIp}</TableCell>
                          <TableCell>{row.sourcePort}</TableCell>
                          <TableCell className="font-mono font-medium text-blue-600">
                            {row.natIp}
                          </TableCell>
                          <TableCell className="font-medium text-blue-600">
                            {row.natPort}
                          </TableCell>
                          <TableCell className="font-mono">{row.destIp}</TableCell>
                          <TableCell>{row.destPort}</TableCell>
                          <TableCell>{getProtocolBadge(row.protocol)}</TableCell>
                          <TableCell className="text-sm">{row.user}</TableCell>
                          <TableCell>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleCopyRow(row)}
                            >
                              <Copy className="h-3 w-3" />
                            </Button>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              ) : hasSearched ? (
                <Alert>
                  <Search className="h-4 w-4" />
                  <AlertDescription>
                    Nenhum log encontrado com os critérios especificados. 
                    Tente ajustar os filtros ou verificar se os dados estão sendo recebidos corretamente.
                  </AlertDescription>
                </Alert>
              ) : null}
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}