#!/bin/bash

# Script para configurar Elasticsearch com templates
# Deve ser executado após o Elasticsearch estar rodando

set -e

ELASTIC_URL="${1:-http://localhost:9200}"
ELASTIC_USER="${2:-elastic}"
ELASTIC_PASSWORD="${3:-changeme}"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Aguardar Elasticsearch estar disponível
wait_for_elasticsearch() {
    log_info "Aguardando Elasticsearch estar disponível..."
    
    for i in {1..30}; do
        if curl -s -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" "${ELASTIC_URL}/_cluster/health" > /dev/null; then
            log_success "Elasticsearch está disponível"
            return 0
        fi
        echo "Tentativa $i/30..."
        sleep 10
    done
    
    log_error "Elasticsearch não ficou disponível após 5 minutos"
    exit 1
}

# Criar template de índice
create_index_template() {
    log_info "Criando template de índice..."
    
    curl -X PUT "${ELASTIC_URL}/_index_template/cgnat-logs" \
        -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d @elasticsearch/config/cgnat-template.json
    
    log_success "Template de índice criado"
}

# Criar índice inicial
create_initial_index() {
    log_info "Criando índice inicial..."
    
    TODAY=$(date +%Y.%m.%d)
    
    curl -X PUT "${ELASTIC_URL}/cgnat-logs-${TODAY}" \
        -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "aliases": {
                "cgnat-logs": {}
            }
        }'
    
    log_success "Índice inicial criado"
}

# Configurar repositório de snapshot
create_snapshot_repository() {
    log_info "Configurando repositório de snapshot..."
    
    curl -X PUT "${ELASTIC_URL}/_snapshot/local_backup" \
        -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "type": "fs",
            "settings": {
                "location": "/usr/share/elasticsearch/backup",
                "compress": true
            }
        }'
    
    log_success "Repositório de snapshot configurado"
}

# Função principal
main() {
    log_info "Configurando Elasticsearch para Portal CGNAT..."
    
    wait_for_elasticsearch
    create_index_template
    create_initial_index
    create_snapshot_repository
    
    log_success "Configuração do Elasticsearch concluída!"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi