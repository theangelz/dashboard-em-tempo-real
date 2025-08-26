#!/bin/bash

# Script para corrigir problemas na instalação

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
    log_error "Este script deve ser executado como root"
    exit 1
fi

log_info "Corrigindo instalação do Portal CGNAT..."

# Ir para o diretório do portal
cd /opt/cgnat-portal

# Parar containers existentes
log_info "Parando containers existentes..."
docker compose down || true
docker system prune -f

# Verificar memória disponível
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
log_info "Memória total disponível: ${TOTAL_MEM}MB"

if [ $TOTAL_MEM -lt 2048 ]; then
    ES_MEM="512m"
    LS_MEM="256m"
    log_warning "Pouca memória detectada. Usando configuração mínima."
else
    ES_MEM="1g"
    LS_MEM="512m"
fi

# Criar docker-compose.yml ultra-simplificado
log_info "Criando docker-compose.yml ultra-simplificado..."
cat > docker-compose.yml << EOF
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: cgnat-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms${ES_MEM} -Xmx${ES_MEM}"
      - ELASTIC_PASSWORD=\${ELASTIC_PASSWORD:-changeme}
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
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
      - "LS_JAVA_OPTS=-Xms${LS_MEM} -Xmx${LS_MEM}"
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
      - ./portal:/usr/share/nginx/html
    ports:
      - "7880:80"
    networks:
      - cgnat-network
    restart: unless-stopped

volumes:
  elasticsearch_data:
    driver: local

networks:
  cgnat-network:
    driver: bridge
EOF

# Criar pipeline básico do Logstash
log_info "Criando pipeline básico do Logstash..."
mkdir -p logstash/pipeline
cat > logstash/pipeline/cgnat.conf << 'EOF'
input {
  tcp {
    port => 5514
    type => "cgnat"
  }
  
  udp {
    port => 5514
    type => "cgnat"
  }
}

filter {
  if [type] == "cgnat" {
    # Parse básico de syslog
    grok {
      match => { 
        "message" => "<%{POSINT:priority}>%{GREEDYDATA:syslog_message}" 
      }
    }

    # Parse key=value
    kv {
      source => "syslog_message"
      field_split => " "
      value_split => "="
    }
    
    # Adicionar timestamp
    mutate {
      add_field => { "[@metadata][index]" => "cgnat-logs-%{+YYYY.MM.dd}" }
    }
  }
}

output {
  if [type] == "cgnat" {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "%{[@metadata][index]}"
    }
  }
  
  # Debug
  stdout { codec => dots }
}
EOF

# Criar portal HTML básico
log_info "Criando portal HTML básico..."
mkdir -p portal
cat > portal/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Portal CGNAT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { background: #f0f8ff; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .config { background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0; }
        pre { background: #eee; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .links a { display: inline-block; margin: 10px 15px 10px 0; padding: 10px 20px; background: #007cba; color: white; text-decoration: none; border-radius: 3px; }
        .links a:hover { background: #005a87; }
        h1 { color: #333; }
        h2 { color: #666; border-bottom: 2px solid #ddd; padding-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ Portal de Logs NAT/CGNAT</h1>
        <p>Sistema de gerenciamento de logs em conformidade com a legislação brasileira.</p>
        
        <div class="status">
            <h2>📊 Status do Sistema</h2>
            <ul>
                <li>✅ <strong>Elasticsearch</strong>: Armazenamento de logs</li>
                <li>✅ <strong>Logstash</strong>: Recebendo logs na porta 5514</li>
                <li>✅ <strong>Kibana</strong>: Interface de visualização</li>
                <li>✅ <strong>Portal</strong>: Interface web ativa</li>
            </ul>
        </div>
        
        <div class="config">
            <h2>⚙️ Configuração de Equipamentos</h2>
            <p>Configure seus equipamentos CGNAT/Firewall para enviar logs via syslog:</p>
            <pre><strong>Servidor:</strong> <span id="server-ip">SEU_IP_AQUI</span>
<strong>Porta TCP:</strong> 5514
<strong>Porta UDP:</strong> 5514 (opcional)
<strong>Formato:</strong> key=value

<strong>Exemplo:</strong>
orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17</pre>
        </div>
        
        <div class="links">
            <h2>🔗 Links Úteis</h2>
            <a href="http://localhost:5601" target="_blank">📈 Kibana - Visualização</a>
            <a href="http://localhost:9200/_cluster/health" target="_blank">🔍 Status Elasticsearch</a>
            <a href="#" onclick="testConnection()">🧪 Testar Conexão</a>
        </div>
        
        <div class="config">
            <h2>📋 Comandos Úteis</h2>
            <pre><strong>Ver status:</strong>
cd /opt/cgnat-portal && docker compose ps

<strong>Ver logs:</strong>
docker compose logs -f

<strong>Testar envio de log:</strong>
echo "orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17" | nc localhost 5514

<strong>Verificar índices:</strong>
curl http://localhost:9200/_cat/indices</pre>
        </div>
    </div>
    
    <script>
        // Detectar IP do servidor
        if (window.location.hostname !== 'localhost') {
            document.getElementById('server-ip').textContent = window.location.hostname;
        }
        
        function testConnection() {
            fetch('http://localhost:9200/_cluster/health')
                .then(response => response.json())
                .then(data => {
                    alert('✅ Elasticsearch Status: ' + data.status);
                })
                .catch(error => {
                    alert('❌ Erro ao conectar com Elasticsearch');
                });
        }
    </script>
</body>
</html>
EOF

# Ajustar permissões
chown -R 1000:1000 /opt/cgnat-portal/elasticsearch 2>/dev/null || true

# Iniciar serviços
log_info "Iniciando serviços ultra-simplificados..."
docker compose up -d

# Aguardar um pouco
log_info "Aguardando serviços inicializarem (30 segundos)..."
sleep 30

# Verificar status
log_info "Verificando status dos serviços..."
docker compose ps

# Testar Elasticsearch
log_info "Testando Elasticsearch..."
if curl -s http://localhost:9200/_cluster/health | grep -q "yellow\|green"; then
    log_success "Elasticsearch está funcionando!"
else
    log_error "Elasticsearch ainda não está pronto. Aguarde mais alguns minutos."
fi

# Mostrar informações
log_success "Correção concluída!"
echo ""
log_info "=== INFORMAÇÕES DE ACESSO ==="
echo "Portal Web: http://$(hostname -I | awk '{print $1}'):7880"
echo "Kibana: http://$(hostname -I | awk '{print $1}'):5601"
echo "Elasticsearch: http://$(hostname -I | awk '{print $1}'):9200"
echo ""
log_info "=== TESTAR LOGS ==="
echo "Enviar log de teste:"
echo 'echo "orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17" | nc localhost 5514'
echo ""
log_info "=== VERIFICAR LOGS ==="
echo "curl http://localhost:9200/_cat/indices"
echo "curl http://localhost:9200/cgnat-logs-*/_search?pretty"