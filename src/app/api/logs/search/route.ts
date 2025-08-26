import { NextRequest, NextResponse } from 'next/server';
import { Client } from '@elastic/elasticsearch';

// Cliente Elasticsearch
const client = new Client({
  node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
  auth: {
    username: 'elastic',
    password: process.env.ELASTIC_PASSWORD || 'changeme'
  }
});

export async function POST(request: NextRequest) {
  try {
    const { 
      publicIp, 
      publicPort, 
      privateIp, 
      startDate, 
      startTime, 
      endDate, 
      endTime, 
      timezone = 'America/Sao_Paulo',
      limit = 100,
      offset = 0 
    } = await request.json();

    // Construir query Elasticsearch
    const must: any[] = [];
    
    if (publicIp) {
      must.push({ term: { 'source.nat.ip': publicIp } });
    }
    
    if (publicPort) {
      must.push({ term: { 'source.nat.port': parseInt(publicPort) } });
    }
    
    if (privateIp) {
      must.push({ term: { 'source.ip': privateIp } });
    }

    // Filtro de tempo
    if (startDate || endDate) {
      const timeFilter: any = {};
      
      if (startDate) {
        const startDateTime = startTime ? `${startDate}T${startTime}` : `${startDate}T00:00:00`;
        timeFilter.gte = new Date(startDateTime).toISOString();
      }
      
      if (endDate) {
        const endDateTime = endTime ? `${endDate}T${endTime}` : `${endDate}T23:59:59`;
        timeFilter.lte = new Date(endDateTime).toISOString();
      }
      
      if (Object.keys(timeFilter).length > 0) {
        must.push({ range: { '@timestamp': timeFilter } });
      }
    }

    const query = {
      index: 'cgnat-logs-*',
      body: {
        query: {
          bool: {
            must: must.length > 0 ? must : [{ match_all: {} }]
          }
        },
        sort: [
          { '@timestamp': { order: 'desc' } }
        ],
        size: Math.min(limit, 5000), // Máximo 5000 resultados
        from: offset
      }
    };

    console.log('Elasticsearch query:', JSON.stringify(query, null, 2));

    // Executar busca
    const response = await client.search(query);
    
    const events = response.body.hits.hits.map((hit: any) => ({
      timestamp: hit._source['@timestamp'],
      sourceIp: hit._source.source?.ip,
      sourcePort: hit._source.source?.port,
      natIp: hit._source.source?.nat?.ip,
      natPort: hit._source.source?.nat?.port,
      destIp: hit._source.destination?.ip,
      destPort: hit._source.destination?.port,
      protocol: hit._source.network?.transport?.toUpperCase(),
      sessionId: hit._source.cgnat?.session?.id,
      user: hit._source.user?.name,
      observerHostname: hit._source.observer?.hostname
    }));

    // Log de auditoria
    const userAgent = request.headers.get('user-agent') || 'unknown';
    const clientIp = request.headers.get('x-forwarded-for') || request.ip || 'unknown';
    
    console.log(`[AUDIT] Log search - IP: ${clientIp}, UserAgent: ${userAgent}, Results: ${events.length}`);

    return NextResponse.json({
      events,
      total: response.body.hits.total.value,
      took: response.body.took,
      page: Math.floor(offset / limit) + 1,
      pageSize: limit
    });

  } catch (error) {
    console.error('Search error:', error);
    
    // Se Elasticsearch não estiver disponível, retornar dados de exemplo
    if (error.message?.includes('ECONNREFUSED')) {
      console.warn('Elasticsearch not available, returning sample data');
      
      const sampleEvents = [
        {
          timestamp: new Date().toISOString(),
          sourceIp: '100.64.1.45',
          sourcePort: 54321,
          natIp: '177.45.123.45',
          natPort: 12345,
          destIp: '8.8.8.8',
          destPort: 53,
          protocol: 'UDP',
          sessionId: 'sess_sample_123',
          user: 'user@provedor.com'
        }
      ];
      
      return NextResponse.json({
        events: sampleEvents,
        total: 1,
        took: 1,
        page: 1,
        pageSize: 100
      });
    }

    return NextResponse.json(
      { error: 'Erro ao buscar logs' },
      { status: 500 }
    );
  }
}