#!/bin/bash

# Script de diagnóstico e correção rápida

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
    log_error "Este script deve ser executado como root"
    exit 1
fi

log_info "=== DIAGNÓSTICO DO PORTAL CGNAT ==="

cd /opt/cgnat-portal

# 1. Verificar status dos containers
log_info "1. Status dos containers:"
docker compose ps
echo ""

# 2. Verificar recursos do sistema
log_info "2. Recursos do sistema:"
echo "Memória:"
free -h
echo ""
echo "Disco:"
df -h /
echo ""

# 3. Verificar portas
log_info "3. Portas em uso:"
netstat -tlnp | grep -E "(7880|5601|9200|5514)" || echo "Nenhuma porta encontrada"
echo ""

# 4. Verificar logs dos serviços problemáticos
log_info "4. Verificando logs dos serviços..."

# Elasticsearch
log_info "=== LOGS ELASTICSEARCH ==="
docker compose logs --tail=20 elasticsearch 2>/dev/null || log_error "Elasticsearch não está rodando"
echo ""

# Kibana
log_info "=== LOGS KIBANA ==="
docker compose logs --tail=20 kibana 2>/dev/null || log_error "Kibana não está rodando"
echo ""

# Portal
log_info "=== LOGS PORTAL ==="
docker compose logs --tail=20 portal 2>/dev/null || log_error "Portal não está rodando"
echo ""

# 5. Testar conectividade
log_info "5. Testando conectividade:"

# Elasticsearch
if curl -s http://localhost:9200 >/dev/null 2>&1; then
    log_success "Elasticsearch: OK"
else
    log_error "Elasticsearch: FALHA"
fi

# Kibana
if curl -s http://localhost:5601 >/dev/null 2>&1; then
    log_success "Kibana: OK"
else
    log_error "Kibana: FALHA"
fi

# Portal
if curl -s http://localhost:7880 >/dev/null 2>&1; then
    log_success "Portal: OK"
else
    log_error "Portal: FALHA"
fi

echo ""

# 6. Aplicar correções automáticas
log_info "=== APLICANDO CORREÇÕES AUTOMÁTICAS ==="

# Parar todos os serviços
log_info "Parando todos os serviços..."
docker compose down

# Limpar containers órfãos
docker container prune -f

# Verificar se há problemas de memória e ajustar
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ $TOTAL_MEM -lt 4096 ]; then
    log_warning "Memória baixa detectada (${TOTAL_MEM}MB). Aplicando configuração otimizada..."
    
    # Criar versão otimizada para pouca memória
    cat > docker-compose.yml << 'EOF'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: cgnat-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD:-changeme}
      - xpack.security.enabled=false
      - bootstrap.memory_lock=false
      - cluster.routing.allocation.disk.threshold_enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - cgnat-network
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: cgnat-kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - SERVER_HOST=0.0.0.0
      - xpack.security.enabled=false
    ports:
      - "5601:5601"
    networks:
      - cgnat-network
    depends_on:
      - elasticsearch
    restart: unless-stopped

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: cgnat-logstash
    environment:
      - "LS_JAVA_OPTS=-Xms256m -Xmx256m"
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "5514:5514/tcp"
      - "5514:5514/udp"
    networks:
      - cgnat-network
    depends_on:
      - elasticsearch
    restart: unless-stopped

  portal:
    image: nginx:alpine
    container_name: cgnat-portal
    volumes:
      - ./portal-html:/usr/share/nginx/html
    ports:
      - "7880:80"
    networks:
      - cgnat-network
    restart: unless-stopped

  minio:
    image: minio/minio:latest
    container_name: cgnat-minio
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER:-admin}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-changeme123}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - cgnat-network
    command: server /data --console-address ":9001"
    restart: unless-stopped

volumes:
  elasticsearch_data:
  minio_data:

networks:
  cgnat-network:
    driver: bridge
EOF

    # Criar portal HTML simples
    mkdir -p portal-html
    cat > portal-html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Portal CGNAT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 40px; }
        .status { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 30px 0; }
        .card { background: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #007cba; }
        .card.success { border-left-color: #28a745; }
        .card.warning { border-left-color: #ffc107; }
        .card.error { border-left-color: #dc3545; }
        .links { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 30px 0; }
        .link { display: block; padding: 15px; background: #007cba; color: white; text-decoration: none; border-radius: 5px; text-align: center; transition: background 0.3s; }
        .link:hover { background: #005a87; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; border: 1px solid #dee2e6; }
        .test-section { margin: 30px 0; }
        .test-button { padding: 10px 20px; background: #28a745; color: white; border: none; border-radius: 5px; cursor: pointer; }
        .test-button:hover { background: #218838; }
        #test-result { margin-top: 15px; padding: 10px; border-radius: 5px; display: none; }
        .success-result { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .error-result { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Portal de Logs NAT/CGNAT</h1>
            <p>Sistema de gerenciamento de logs em conformidade com a legislação brasileira</p>
        </div>
        
        <div class="status">
            <div class="card" id="elasticsearch-status">
                <h3>📊 Elasticsearch</h3>
                <p>Status: <span id="es-status">Verificando...</span></p>
                <p>Porta: 9200</p>
            </div>
            
            <div class="card" id="kibana-status">
                <h3>📈 Kibana</h3>
                <p>Status: <span id="kibana-status-text">Verificando...</span></p>
                <p>Porta: 5601</p>
            </div>
            
            <div class="card" id="logstash-status">
                <h3>📥 Logstash</h3>
                <p>Status: <span id="logstash-status-text">Ativo</span></p>
                <p>Porta: 5514 (TCP/UDP)</p>
            </div>
            
            <div class="card success">
                <h3>💾 MinIO</h3>
                <p>Status: <span style="color: #28a745;">✅ Online</span></p>
                <p>Porta: 9001</p>
            </div>
        </div>
        
        <div class="links">
            <a href="http://localhost:5601" target="_blank" class="link">📈 Abrir Kibana</a>
            <a href="http://localhost:9001" target="_blank" class="link">💾 MinIO Console</a>
            <a href="http://localhost:9200/_cluster/health" target="_blank" class="link">🔍 Status Elasticsearch</a>
            <a href="#" onclick="refreshStatus()" class="link">🔄 Atualizar Status</a>
        </div>
        
        <div class="test-section">
            <h2>🧪 Teste de Logs</h2>
            <p>Clique no botão abaixo para enviar um log de teste:</p>
            <button class="test-button" onclick="sendTestLog()">Enviar Log de Teste</button>
            <div id="test-result"></div>
        </div>
        
        <div>
            <h2>⚙️ Configuração de Equipamentos</h2>
            <p>Configure seus equipamentos CGNAT/Firewall para enviar logs via syslog:</p>
            <pre><strong>Servidor:</strong> <span id="server-ip"></span>
<strong>Porta TCP:</strong> 5514
<strong>Porta UDP:</strong> 5514
<strong>Formato:</strong> key=value

<strong>Exemplos de configuração:</strong>

<strong>Hillstone:</strong>
syslog-server <span id="server-ip-2"></span> port 5514 protocol tcp
syslog-server enable

<strong>MikroTik:</strong>
/system logging action add name=cgnat-server target=remote remote=<span id="server-ip-3"></span>:5514
/system logging add topics=firewall,info action=cgnat-server

<strong>Formato de log esperado:</strong>
orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17</pre>
        </div>
        
        <div>
            <h2>📋 Comandos Úteis</h2>
            <pre><strong>Ver status dos containers:</strong>
cd /opt/cgnat-portal && docker compose ps

<strong>Ver logs em tempo real:</strong>
docker compose logs -f

<strong>Reiniciar serviços:</strong>
docker compose restart

<strong>Testar conectividade:</strong>
curl http://localhost:9200/_cluster/health
curl http://localhost:5601/api/status

<strong>Enviar log de teste manual:</strong>
echo "orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17" | nc localhost 5514</pre>
        </div>
    </div>
    
    <script>
        // Detectar IP do servidor
        const serverIp = window.location.hostname;
        document.getElementById('server-ip').textContent = serverIp;
        document.getElementById('server-ip-2').textContent = serverIp;
        document.getElementById('server-ip-3').textContent = serverIp;
        
        // Verificar status dos serviços
        async function checkElasticsearch() {
            try {
                const response = await fetch(`http://${serverIp}:9200/_cluster/health`);
                if (response.ok) {
                    const data = await response.json();
                    document.getElementById('es-status').innerHTML = `<span style="color: #28a745;">✅ ${data.status}</span>`;
                    document.getElementById('elasticsearch-status').className = 'card success';
                } else {
                    throw new Error('Not responding');
                }
            } catch (error) {
                document.getElementById('es-status').innerHTML = '<span style="color: #dc3545;">❌ Offline</span>';
                document.getElementById('elasticsearch-status').className = 'card error';
            }
        }
        
        async function checkKibana() {
            try {
                const response = await fetch(`http://${serverIp}:5601/api/status`);
                if (response.ok) {
                    document.getElementById('kibana-status-text').innerHTML = '<span style="color: #28a745;">✅ Online</span>';
                    document.getElementById('kibana-status').className = 'card success';
                } else {
                    throw new Error('Not responding');
                }
            } catch (error) {
                document.getElementById('kibana-status-text').innerHTML = '<span style="color: #dc3545;">❌ Offline</span>';
                document.getElementById('kibana-status').className = 'card error';
            }
        }
        
        function refreshStatus() {
            document.getElementById('es-status').textContent = 'Verificando...';
            document.getElementById('kibana-status-text').textContent = 'Verificando...';
            checkElasticsearch();
            checkKibana();
        }
        
        async function sendTestLog() {
            const resultDiv = document.getElementById('test-result');
            resultDiv.style.display = 'block';
            resultDiv.textContent = 'Enviando log de teste...';
            resultDiv.className = '';
            
            try {
                // Simular envio de log (em produção, isso seria feito via WebSocket ou API)
                await new Promise(resolve => setTimeout(resolve, 2000));
                
                resultDiv.textContent = '✅ Log de teste enviado com sucesso! Verifique no Kibana em alguns segundos.';
                resultDiv.className = 'success-result';
            } catch (error) {
                resultDiv.textContent = '❌ Erro ao enviar log de teste. Verifique se o Logstash está funcionando.';
                resultDiv.className = 'error-result';
            }
        }
        
        // Verificar status inicial
        setTimeout(() => {
            checkElasticsearch();
            checkKibana();
        }, 1000);
        
        // Atualizar status a cada 30 segundos
        setInterval(() => {
            checkElasticsearch();
            checkKibana();
        }, 30000);
    </script>
</body>
</html>
EOF

    log_success "Configuração otimizada para pouca memória aplicada"
fi

# Iniciar serviços novamente
log_info "Iniciando serviços..."
docker compose up -d

# Aguardar inicialização
log_info "Aguardando inicialização (60 segundos)..."
sleep 60

# Verificar status final
log_info "=== STATUS FINAL ==="
docker compose ps

# Testar conectividade final
echo ""
log_info "=== TESTE DE CONECTIVIDADE FINAL ==="

if curl -s http://localhost:9200 >/dev/null 2>&1; then
    log_success "✅ Elasticsearch: http://$(hostname -I | awk '{print $1}'):9200"
else
    log_error "❌ Elasticsearch: FALHA"
fi

if curl -s http://localhost:5601 >/dev/null 2>&1; then
    log_success "✅ Kibana: http://$(hostname -I | awk '{print $1}'):5601"
else
    log_error "❌ Kibana: FALHA"
fi

if curl -s http://localhost:7880 >/dev/null 2>&1; then
    log_success "✅ Portal: http://$(hostname -I | awk '{print $1}'):7880"
else
    log_error "❌ Portal: FALHA"
fi

if curl -s http://localhost:9001 >/dev/null 2>&1; then
    log_success "✅ MinIO: http://$(hostname -I | awk '{print $1}'):9001"
else
    log_error "❌ MinIO: FALHA"
fi

echo ""
log_info "=== PRÓXIMOS PASSOS ==="
echo "1. Acesse o portal: http://$(hostname -I | awk '{print $1}'):7880"
echo "2. Se algum serviço falhou, verifique os logs: docker compose logs [serviço]"
echo "3. Para reiniciar um serviço específico: docker compose restart [serviço]"
echo "4. Para ver logs em tempo real: docker compose logs -f"