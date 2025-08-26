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
        unzip
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

# Criar script de backup
create_backup_script() {
    log_info "Criando script de backup..."
    
    cat > /opt/cgnat-portal/scripts/backup.sh << 'EOF'
#!/bin/bash

# Script de backup automático
# Executa snapshots do Elasticsearch

ELASTIC_URL="http://localhost:9200"
ELASTIC_USER="elastic"
ELASTIC_PASSWORD=$(grep ELASTIC_PASSWORD /opt/cgnat-portal/.env | cut -d'=' -f2)

DATE=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_NAME="cgnat-backup-${DATE}"

# Criar snapshot
curl -X PUT "${ELASTIC_URL}/_snapshot/local_backup/${SNAPSHOT_NAME}" \
  -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "cgnat-logs-*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'

# Log do backup
echo "$(date): Backup ${SNAPSHOT_NAME} iniciado" >> /var/log/cgnat-portal/backup.log
EOF

    chmod +x /opt/cgnat-portal/scripts/backup.sh
    
    # Criar cron job para backup diário
    echo "0 2 * * * root /opt/cgnat-portal/scripts/backup.sh" > /etc/cron.d/cgnat-backup
    
    log_success "Script de backup criado"
}

# Criar script de monitoramento
create_monitoring_script() {
    log_info "Criando script de monitoramento..."
    
    cat > /opt/cgnat-portal/scripts/health-check.sh << 'EOF'
#!/bin/bash

# Script de monitoramento de saúde do sistema

LOG_FILE="/var/log/cgnat-portal/health.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Função para log
log_health() {
    echo "[$DATE] $1" >> $LOG_FILE
}

# Verificar Elasticsearch
if curl -s http://localhost:9200/_cluster/health | grep -q "green\|yellow"; then
    log_health "Elasticsearch: OK"
else
    log_health "Elasticsearch: ERRO"
fi

# Verificar Kibana
if curl -s http://localhost:5601/api/status | grep -q "available"; then
    log_health "Kibana: OK"
else
    log_health "Kibana: ERRO"
fi

# Verificar Portal
if curl -s http://localhost:7880 > /dev/null; then
    log_health "Portal: OK"
else
    log_health "Portal: ERRO"
fi

# Verificar espaço em disco
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    log_health "Disco: ALERTA - ${DISK_USAGE}% usado"
else
    log_health "Disco: OK - ${DISK_USAGE}% usado"
fi
EOF

    chmod +x /opt/cgnat-portal/scripts/health-check.sh
    
    # Criar cron job para monitoramento a cada 5 minutos
    echo "*/5 * * * * root /opt/cgnat-portal/scripts/health-check.sh" > /etc/cron.d/cgnat-health
    
    log_success "Script de monitoramento criado"
}

# Criar serviço systemd
create_systemd_service() {
    log_info "Criando serviço systemd..."
    
    cat > /etc/systemd/system/cgnat-portal.service << EOF
[Unit]
Description=CGNAT Portal
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/cgnat-portal
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable cgnat-portal.service
    
    log_success "Serviço systemd criado"
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
    create_backup_script
    create_monitoring_script
    create_systemd_service
    
    log_success "Instalação concluída!"
    log_info "Próximos passos:"
    echo "1. Copie os arquivos do projeto para /opt/cgnat-portal/"
    echo "2. Execute: cd /opt/cgnat-portal && docker compose up -d"
    echo "3. Acesse o portal em http://$(hostname -I | awk '{print $1}'):7880"
    echo "4. Acesse o Kibana em http://$(hostname -I | awk '{print $1}'):5601"
    echo ""
    log_info "Credenciais salvas em /opt/cgnat-portal/.env"
    log_warning "IMPORTANTE: Altere as senhas padrão antes de usar em produção!"
}

# Executar função principal
main "$@"