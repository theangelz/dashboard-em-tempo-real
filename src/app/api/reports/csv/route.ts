import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';

export async function POST(request: NextRequest) {
  try {
    const { searchParams, events } = await request.json();

    // Cabeçalho CSV
    const headers = [
      'timestamp',
      'source_ip',
      'source_port',
      'nat_ip',
      'nat_port',
      'destination_ip',
      'destination_port',
      'protocol',
      'session_id',
      'user',
      'observer_hostname'
    ];

    // Converter eventos para CSV
    const csvRows = [headers.join(',')];
    
    events.forEach((event: any) => {
      const row = [
        event.timestamp || '',
        event.sourceIp || '',
        event.sourcePort || '',
        event.natIp || '',
        event.natPort || '',
        event.destIp || '',
        event.destPort || '',
        event.protocol || '',
        event.sessionId || '',
        event.user || '',
        event.observerHostname || ''
      ];
      
      // Escapar campos que contêm vírgulas ou aspas
      const escapedRow = row.map(field => {
        const str = String(field);
        if (str.includes(',') || str.includes('"') || str.includes('\n')) {
          return `"${str.replace(/"/g, '""')}"`;
        }
        return str;
      });
      
      csvRows.push(escapedRow.join(','));
    });

    const csvContent = csvRows.join('\n');

    // Metadados do relatório
    const timestamp = new Date().toISOString();
    const metadata = {
      generated_at: timestamp,
      search_criteria: searchParams,
      total_records: events.length,
      timezone: searchParams.timezone || 'America/Sao_Paulo'
    };

    // Hash SHA-256 do conteúdo
    const hash = crypto.createHash('sha256').update(csvContent).digest('hex');

    // Adicionar metadados como comentários no início do CSV
    const finalCsv = [
      `# Relatório de Logs NAT/CGNAT`,
      `# Gerado em: ${timestamp}`,
      `# Total de registros: ${events.length}`,
      `# Hash SHA-256: ${hash}`,
      `# Critérios de busca: ${JSON.stringify(searchParams)}`,
      `#`,
      csvContent
    ].join('\n');

    // Log de auditoria
    const userAgent = request.headers.get('user-agent') || 'unknown';
    const clientIp = request.headers.get('x-forwarded-for') || request.ip || 'unknown';
    
    console.log(`[AUDIT] CSV generated - IP: ${clientIp}, UserAgent: ${userAgent}, Hash: ${hash}, Records: ${events.length}`);

    return new NextResponse(finalCsv, {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="logs-cgnat-${Date.now()}.csv"`,
        'X-Report-Hash': hash,
        'X-Report-Records': events.length.toString()
      }
    });

  } catch (error) {
    console.error('CSV generation error:', error);
    return NextResponse.json(
      { error: 'Erro ao gerar relatório CSV' },
      { status: 500 }
    );
  }
}