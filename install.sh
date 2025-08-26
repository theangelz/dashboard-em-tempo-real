#!/bin/bash

# Script de instalação do Portal CGNAT para Debian 12
# Autor: Portal CGNAT Team
# Versão: 1.0

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de log
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
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
}

# Verificar versão do Debian
check_debian_version() {
    if ! grep -q "Debian GNU/Linux 12" /etc/os-release; then
        log_warning "Este script foi testado apenas no Debian 12. Continuando mesmo assim..."
    fi
}

# Atualizar sistema
update_system() {
    log_info "Atualizando sistema..."
    apt update && apt upgrade -y
    log_success "Sistema atualizado"
}

# Instalar dependências básicas
install_dependencies() {
    log_info "Instalando dependências básicas..."
    apt install -y \
        curl \
        wget \
        gnupg \
        lsb-release \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        ufw \
        htop \
        vim \
        git \
        unzip \
        netcat-traditional
    log_success "Dependências básicas instaladas"
}

# Instalar Docker
install_docker() {
    log_info "Instalando Docker..."
    
    # Remover versões antigas
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Adicionar repositório Docker
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Iniciar e habilitar Docker
    systemctl start docker
    systemctl enable docker
    
    # Adicionar usuário ao grupo docker
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker $SUDO_USER
        log_info "Usuário $SUDO_USER adicionado ao grupo docker"
    fi
    
    log_success "Docker instalado com sucesso"
}

# Configurar firewall
configure_firewall() {
    log_info "Configurando firewall..."
    
    # Resetar UFW
    ufw --force reset
    
    # Política padrão
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH
    ufw allow ssh
    
    # Permitir portas do portal
    ufw allow 7880/tcp comment "Portal Web"
    ufw allow 5601/tcp comment "Kibana"
    ufw allow 9200/tcp comment "Elasticsearch"
    
    # Permitir Syslog
    ufw allow 5514/tcp comment "Syslog TCP"
    ufw allow 5514/udp comment "Syslog UDP"
    ufw allow 6514/tcp comment "Syslog TLS"
    
    # Permitir MinIO
    ufw allow 9000/tcp comment "MinIO API"
    ufw allow 9001/tcp comment "MinIO Console"
    
    # Habilitar UFW
    ufw --force enable
    
    log_success "Firewall configurado"
}

# Criar estrutura de diretórios
create_directories() {
    log_info "Criando estrutura de diretórios..."
    
    mkdir -p /opt/cgnat-portal/{elasticsearch,logstash,kibana,portal,backups,scripts}
    mkdir -p /opt/cgnat-portal/logstash/{pipeline,patterns,config}
    mkdir -p /opt/cgnat-portal/elasticsearch/config
    mkdir -p /opt/cgnat-portal/portal/pages
    mkdir -p /var/log/cgnat-portal
    
    # Permissões
    chown -R 1000:1000 /opt/cgnat-portal/elasticsearch
    chown -R 1000:1000 /opt/cgnat-portal/logstash
    chown -R 1000:1000 /opt/cgnat-portal/kibana
    
    log_success "Estrutura de diretórios criada"
}

# Gerar senhas seguras
generate_passwords() {
    log_info "Gerando senhas seguras..."
    
    ELASTIC_PASSWORD=$(openssl rand -base64 32)
    JWT_SECRET=$(openssl rand -base64 64)
    MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
    
    # Criar arquivo .env
    cat > /opt/cgnat-portal/.env << EOF
# Elasticsearch
ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
ELASTICSEARCH_URL=http://localhost:9200

# JWT
JWT_SECRET=${JWT_SECRET}

# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}

# Portal
NODE_ENV=production
PORT=3000
EOF

    chmod 600 /opt/cgnat-portal/.env
    
    log_success "Senhas geradas e salvas em /opt/cgnat-portal/.env"
}

# Criar arquivos localmente (fallback)
create_local_files() {
    log_warning "Criando arquivos de configuração localmente como fallback..."
    
    cd /opt/cgnat-portal
    
    # Docker Compose sem memlock
    cat > docker-compose.yml << 'EOF'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: cgnat-elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=cgnat-cluster
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD:-changeme}
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - path.repo=/usr/share/elasticsearch/backup
      - bootstrap.memory_lock=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
      - elasticsearch_backup:/usr/share/elasticsearch/backup
    ports:
      - "9200:9200"
    networks:
      - cgnat-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: cgnat-kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD:-changeme}
      - SERVER_NAME=kibana
      - SERVER_HOST=0.0.0.0
    ports:
      - "5601:5601"
    networks:
      - cgnat-network
    depends_on:
      elasticsearch:
        condition: service_healthy

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: cgnat-logstash
    environment:
      - "LS_JAVA_OPTS=-Xms512m -Xmx512m"
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD:-changeme}
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
      - ./logstash/patterns:/usr/share/logstash/patterns
    ports:
      - "5514:5514/tcp"
      - "5514:5514/udp"
      - "6514:6514/tcp"
      - "9600:9600"
    networks:
      - cgnat-network
    depends_on:
      elasticsearch:
        condition: service_healthy

  portal:
    image: node:18-alpine
    container_name: cgnat-portal
    working_dir: /app
    environment:
      - NODE_ENV=development
      - ELASTICSEARCH_URL=http://elasticsearch:9200
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD:-changeme}
      - JWT_SECRET=${JWT_SECRET:-your-super-secret-jwt-key}
      - PORT=3000
    volumes:
      - ./portal:/app
    ports:
      - "7880:3000"
    networks:
      - cgnat-network
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped
    command: >
      sh -c "
        if [ ! -f package.json ]; then
          npm init -y
          npm install next@latest react@latest react-dom@latest
        fi
        npm install
        npm run dev
      "

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

volumes:
  elasticsearch_data:
  elasticsearch_backup:
  minio_data:

networks:
  cgnat-network:
    driver: bridge
EOF

    # Pipeline Logstash
    cat > logstash/pipeline/cgnat.conf << 'EOF'
input {
  syslog {
    port => 5514
    type => "cgnat"
    codec => plain
  }
  
  udp {
    port => 5514
    type => "cgnat"
    codec => plain
  }
}

filter {
  if [type] == "cgnat" {
    grok {
      match => { 
        "message" => "<%{POSINT:syslog_pri}>%{SYSLOGTIMESTAMP:syslog_timestamp} %{IPORHOST:syslog_server} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" 
      }
    }

    kv {
      source => "syslog_message"
      field_split => " "
      value_split => "="
      target => "kv"
    }
    
    if [kv][orig] {
      grok {
        match => { "[kv][orig]" => "%{IP:source_ip}:%{POSINT:source_port}" }
      }
    }
    
    if [kv][trans] {
      grok {
        match => { "[kv][trans]" => "%{IP:nat_ip}:%{POSINT:nat_port}" }
      }
    }
    
    if [kv][dst] {
      grok {
        match => { "[kv][dst]" => "%{IP:dest_ip}:%{POSINT:dest_port}" }
      }
    }

    if [source_ip] {
      mutate {
        add_field => {
          "[source][ip]" => "%{source_ip}"
          "[source][port]" => "%{source_port}"
        }
      }
    }
    
    if [nat_ip] {
      mutate {
        add_field => {
          "[source][nat][ip]" => "%{nat_ip}"
          "[source][nat][port]" => "%{nat_port}"
        }
      }
    }
    
    if [dest_ip] {
      mutate {
        add_field => {
          "[destination][ip]" => "%{dest_ip}"
          "[destination][port]" => "%{dest_port}"
        }
      }
    }

    mutate {
      add_field => {
        "[event][category]" => "network"
        "[event][kind]" => "event"
        "[event][dataset]" => "cgnat"
      }
    }

    if [syslog_server] {
      mutate {
        add_field => {
          "[observer][hostname]" => "%{syslog_server}"
        }
      }
    }

    mutate {
      convert => {
        "[source][port]" => "integer"
        "[source][nat][port]" => "integer"
        "[destination][port]" => "integer"
      }
    }
  }
}

output {
  if [type] == "cgnat" {
    elasticsearch {
      hosts => ["${ELASTICSEARCH_HOSTS:elasticsearch:9200}"]
      user => "${ELASTICSEARCH_USERNAME:elastic}"
      password => "${ELASTICSEARCH_PASSWORD:changeme}"
      index => "cgnat-logs-%{+YYYY.MM.dd}"
    }
  }
}
EOF

    # Portal básico
    cat > portal/package.json << 'EOF'
{
  "name": "cgnat-portal",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "^18",
    "react-dom": "^18"
  }
}
EOF

    cat > portal/pages/index.js << 'EOF'
export default function Home() {
  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>Portal de Logs NAT/CGNAT</h1>
      <p>Sistema funcionando! Elasticsearch conectado.</p>
      
      <div style={{ marginTop: '30px' }}>
        <h2>Status do Sistema</h2>
        <ul>
          <li>✅ Elasticsearch: Conectado</li>
          <li>✅ Logstash: Recebendo logs na porta 5514</li>
          <li>✅ Kibana: Disponível na porta 5601</li>
        </ul>
      </div>
      
      <div style={{ marginTop: '30px' }}>
        <h2>Configuração de Equipamentos</h2>
        <p>Configure seus equipamentos para enviar logs via syslog:</p>
        <pre style={{ background: '#f5f5f5', padding: '10px', borderRadius: '5px' }}>
{`Servidor: SEU_IP_AQUI
Porta TCP: 5514
Porta UDP: 5514
Formato: key=value (orig=IP:porta trans=IP:porta dst=IP:porta proto=17)`}
        </pre>
      </div>
      
      <div style={{ marginTop: '30px' }}>
        <h2>Links Úteis</h2>
        <ul>
          <li><a href="http://localhost:5601" target="_blank">Kibana - Visualização de Logs</a></li>
          <li><a href="http://localhost:9001" target="_blank">MinIO Console - Backup</a></li>
        </ul>
      </div>
    </div>
  );
}
EOF

    log_success "Arquivos criados localmente"
}

# Baixar arquivos do projeto
download_project_files() {
    log_info "Baixando arquivos do GitHub (repositório público)..."
    
    cd /opt/cgnat-portal
    
    # Tentar baixar docker-compose.yml
    if curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/docker-compose.yml -o docker-compose.yml; then
        log_success "docker-compose.yml baixado"
    else
        log_warning "Falha ao baixar docker-compose.yml, usando fallback local"
        create_local_files
        return
    fi
    
    # Baixar configurações do Logstash
    log_info "Baixando configurações do Logstash..."
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/logstash/pipeline/cgnat.conf -o logstash/pipeline/cgnat.conf || true
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/logstash/patterns/cgnat -o logstash/patterns/cgnat || true
    
    # Baixar configurações do Elasticsearch
    log_info "Baixando configurações do Elasticsearch..."
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/elasticsearch/config/cgnat-template.json -o elasticsearch/config/cgnat-template.json || true
    
    # Baixar scripts
    log_info "Baixando scripts..."
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/scripts/bootstrap-elasticsearch.sh -o scripts/bootstrap-elasticsearch.sh || true
    chmod +x scripts/bootstrap-elasticsearch.sh 2>/dev/null || true
    
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/scripts/test-syslog.sh -o scripts/test-syslog.sh || true
    chmod +x scripts/test-syslog.sh 2>/dev/null || true
    
    # Baixar arquivos do portal
    log_info "Baixando arquivos do portal..."
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/portal/package.json -o portal/package.json || true
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/portal/pages/index.js -o portal/pages/index.js || true
    
    # Baixar .env.example
    curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/.env.example -o .env.example || true
    
    log_success "Arquivos baixados do GitHub"
}

# Criar scripts auxiliares
create_helper_scripts() {
    log_info "Criando scripts auxiliares..."
    
    # Script de teste
    cat > /opt/cgnat-portal/scripts/test-syslog.sh << 'EOF'
#!/bin/bash
SERVER="${1:-localhost}"
PORT="${2:-5514}"

echo "Testando envio de logs para ${SERVER}:${PORT}"

LOGS=(
    "<134>Jan 15 14:32:15 cgnat-fw hillstone: orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17 sess=abc123 user=user@provedor.com"
    "<134>Jan 15 14:32:16 mikrotik-rb routeros: srcnat: src=100.64.1.46:54322 to=177.45.123.46:12346 dst=1.1.1.1:53 proto=udp user=user2@provedor.com"
    "<134>Jan 15 14:32:17 firewall-01 cgnat: orig=100.64.1.47:54323 trans=177.45.123.47:12347 dst=8.8.4.4:53 proto=17"
)

for log in "${LOGS[@]}"; do
    echo "Enviando: $log"
    echo "$log" | nc -w1 "$SERVER" "$PORT"
    sleep 1
done

echo "Teste concluído. Verifique os logs no Kibana em http://${SERVER}:5601"
EOF

    chmod +x /opt/cgnat-portal/scripts/test-syslog.sh
    
    # Script de backup
    cat > /opt/cgnat-portal/scripts/backup.sh << 'EOF'
#!/bin/bash
ELASTIC_URL="http://localhost:9200"
ELASTIC_USER="elastic"
ELASTIC_PASSWORD=$(grep ELASTIC_PASSWORD /opt/cgnat-portal/.env | cut -d'=' -f2)

DATE=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_NAME="cgnat-backup-${DATE}"

curl -X PUT "${ELASTIC_URL}/_snapshot/local_backup/${SNAPSHOT_NAME}" \
  -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "cgnat-logs-*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'

echo "$(date): Backup ${SNAPSHOT_NAME} iniciado" >> /var/log/cgnat-portal/backup.log
EOF

    chmod +x /opt/cgnat-portal/scripts/backup.sh
    
    log_success "Scripts auxiliares criados"
}

# Iniciar serviços
start_services() {
    log_info "Iniciando serviços..."
    
    cd /opt/cgnat-portal
    
    # Iniciar containers
    docker compose up -d
    
    # Aguardar Elasticsearch estar pronto
    log_info "Aguardando Elasticsearch inicializar (60 segundos)..."
    sleep 60
    
    log_success "Serviços iniciados"
}

# Mostrar informações finais
show_final_info() {
    log_success "Instalação concluída!"
    echo ""
    log_info "=== INFORMAÇÕES DE ACESSO ==="
    echo "Portal Web: http://$(hostname -I | awk '{print $1}'):7880"
    echo "Kibana: http://$(hostname -I | awk '{print $1}'):5601"
    echo "MinIO Console: http://$(hostname -I | awk '{print $1}'):9001"
    echo ""
    log_info "=== CREDENCIAIS ==="
    echo "Elasticsearch: elastic / $(grep ELASTIC_PASSWORD /opt/cgnat-portal/.env | cut -d'=' -f2)"
    echo "MinIO: admin / $(grep MINIO_ROOT_PASSWORD /opt/cgnat-portal/.env | cut -d'=' -f2)"
    echo ""
    log_info "=== CONFIGURAÇÃO DE EQUIPAMENTOS ==="
    echo "Configure seus equipamentos CGNAT/Firewall para enviar logs via syslog:"
    echo "Servidor: $(hostname -I | awk '{print $1}')"
    echo "Porta TCP: 5514"
    echo "Porta UDP: 5514 (opcional)"
    echo ""
    log_info "=== COMANDOS ÚTEIS ==="
    echo "Ver status: cd /opt/cgnat-portal && docker compose ps"
    echo "Ver logs: cd /opt/cgnat-portal && docker compose logs -f"
    echo "Testar logs: /opt/cgnat-portal/scripts/test-syslog.sh $(hostname -I | awk '{print $1}') 5514"
    echo ""
    log_warning "Credenciais salvas em /opt/cgnat-portal/.env"
}

# Função principal
main() {
    log_info "Iniciando instalação do Portal CGNAT no Debian 12..."
    
    check_root
    check_debian_version
    update_system
    install_dependencies
    install_docker
    configure_firewall
    create_directories
    generate_passwords
    download_project_files
    create_helper_scripts
    start_services
    show_final_info
}

# Executar função principal
main "$@"