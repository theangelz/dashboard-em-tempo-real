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

# Parar containers existentes
cd /opt/cgnat-portal
log_info "Parando containers existentes..."
docker compose down || true

# Remover containers órfãos
docker container prune -f

# Baixar docker-compose.yml corrigido
log_info "Baixando docker-compose.yml corrigido..."
curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/docker-compose.yml -o docker-compose.yml

# Iniciar serviços novamente
log_info "Iniciando serviços corrigidos..."
docker compose up -d

# Aguardar Elasticsearch
log_info "Aguardando Elasticsearch inicializar (60 segundos)..."
sleep 60

# Verificar status
log_info "Verificando status dos serviços..."
docker compose ps

# Mostrar informações
log_success "Correção concluída!"
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
log_info "=== TESTAR LOGS ==="
echo "Execute: /opt/cgnat-portal/scripts/test-syslog.sh $(hostname -I | awk '{print $1}') 5514"