import { NextRequest, NextResponse } from 'next/server';
import PDFDocument from 'pdfkit';
import crypto from 'crypto';

export async function POST(request: NextRequest) {
  try {
    const { searchParams, events, maxRows = 100 } = await request.json();

    // Limitar número de linhas
    const limitedEvents = events.slice(0, maxRows);

    // Criar PDF
    const doc = new PDFDocument({ margin: 50 });
    const chunks: Buffer[] = [];

    doc.on('data', chunk => chunks.push(chunk));
    
    const pdfPromise = new Promise<Buffer>((resolve) => {
      doc.on('end', () => resolve(Buffer.concat(chunks)));
    });

    // Cabeçalho institucional
    doc.fontSize(20).text('RELATÓRIO DE LOGS NAT/CGNAT', { align: 'center' });
    doc.moveDown();
    
    doc.fontSize(12).text('Portal de Gerência de Logs - Conformidade Legal Brasileira', { align: 'center' });
    doc.moveDown(2);

    // Critérios de busca
    doc.fontSize(14).text('CRITÉRIOS DE BUSCA:', { underline: true });
    doc.moveDown(0.5);
    
    doc.fontSize(10);
    if (searchParams.publicIp) doc.text(`IP Público: ${searchParams.publicIp}`);
    if (searchParams.publicPort) doc.text(`Porta Pública: ${searchParams.publicPort}`);
    if (searchParams.privateIp) doc.text(`IP Privado: ${searchParams.privateIp}`);
    if (searchParams.startDate) doc.text(`Data Início: ${searchParams.startDate} ${searchParams.startTime || ''}`);
    if (searchParams.endDate) doc.text(`Data Fim: ${searchParams.endDate} ${searchParams.endTime || ''}`);
    
    doc.moveDown();

    // Metadados
    const timestamp = new Date().toISOString();
    const timezone = searchParams.timezone || 'America/Sao_Paulo';
    const localTime = new Date().toLocaleString('pt-BR', { timeZone: timezone });
    
    doc.text(`Data/Hora de Geração: ${localTime} (${timezone})`);
    doc.text(`Timestamp UTC: ${timestamp}`);
    doc.text(`Total de Registros: ${limitedEvents.length}`);
    if (limitedEvents.length >= maxRows) {
      doc.text(`ATENÇÃO: Relatório limitado a ${maxRows} registros`);
    }
    doc.moveDown(2);

    // Tabela de dados
    doc.fontSize(12).text('REGISTROS DE LOG:', { underline: true });
    doc.moveDown(0.5);

    // Cabeçalho da tabela
    doc.fontSize(8);
    const tableTop = doc.y;
    const colWidths = [80, 60, 40, 80, 40, 80, 40, 40, 80];
    const headers = ['Timestamp', 'IP Origem', 'Porta', 'IP NAT', 'Porta', 'IP Destino', 'Porta', 'Proto', 'Usuário'];
    
    let x = 50;
    headers.forEach((header, i) => {
      doc.text(header, x, tableTop, { width: colWidths[i], align: 'left' });
      x += colWidths[i];
    });

    // Linha separadora
    doc.moveTo(50, tableTop + 15).lineTo(550, tableTop + 15).stroke();

    // Dados
    let y = tableTop + 20;
    limitedEvents.forEach((event: any) => {
      if (y > 700) { // Nova página se necessário
        doc.addPage();
        y = 50;
      }

      const timestamp = new Date(event.timestamp).toLocaleString('pt-BR', { timeZone: timezone });
      const row = [
        timestamp,
        event.sourceIp || '',
        event.sourcePort?.toString() || '',
        event.natIp || '',
        event.natPort?.toString() || '',
        event.destIp || '',
        event.destPort?.toString() || '',
        event.protocol || '',
        event.user || ''
      ];

      x = 50;
      row.forEach((cell, i) => {
        doc.text(cell, x, y, { width: colWidths[i], align: 'left' });
        x += colWidths[i];
      });
      
      y += 12;
    });

    // Hash SHA-256
    doc.addPage();
    doc.fontSize(12).text('INTEGRIDADE E AUTENTICIDADE:', { underline: true });
    doc.moveDown();

    const content = JSON.stringify({ searchParams, events: limitedEvents, timestamp });
    const hash = crypto.createHash('sha256').update(content).digest('hex');
    
    doc.fontSize(10);
    doc.text(`Hash SHA-256: ${hash}`);
    doc.text(`Algoritmo: SHA-256`);
    doc.text(`Este hash garante a integridade dos dados apresentados.`);
    doc.moveDown();

    doc.text('DECLARAÇÃO DE CONFORMIDADE:');
    doc.text('Este relatório foi gerado em conformidade com os marcos normativos brasileiros para guarda de registros de conexão, atendendo aos requisitos de retenção mínima de 13 meses e controles de acesso adequados.');

    doc.end();

    const pdfBuffer = await pdfPromise;

    // Log de auditoria
    const userAgent = request.headers.get('user-agent') || 'unknown';
    const clientIp = request.headers.get('x-forwarded-for') || request.ip || 'unknown';
    
    console.log(`[AUDIT] PDF generated - IP: ${clientIp}, UserAgent: ${userAgent}, Hash: ${hash}, Records: ${limitedEvents.length}`);

    return new NextResponse(pdfBuffer, {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="relatorio-cgnat-${Date.now()}.pdf"`,
        'X-Report-Hash': hash
      }
    });

  } catch (error) {
    console.error('PDF generation error:', error);
    return NextResponse.json(
      { error: 'Erro ao gerar relatório PDF' },
      { status: 500 }
    );
  }
}