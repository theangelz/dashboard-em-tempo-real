#!/bin/bash

# Script para configurar Elasticsearch com ILM e templates
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

# Criar política ILM
create_ilm_policy() {
    log_info "Criando política ILM..."
    
    curl -X PUT "${ELASTIC_URL}/_ilm/policy/cgnat-policy" \
        -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "policy": {
                "phases": {
                    "hot": {
                        "actions": {
                            "rollover": {
                                "max_age": "1d",
                                "max_size": "50gb"
                            },
                            "set_priority": {
                                "priority": 100
                            }
                        }
                    },
                    "warm": {
                        "min_age": "30d",
                        "actions": {
                            "set_priority": {
                                "priority": 50
                            },
                            "allocate": {
                                "number_of_replicas": 0
                            },
                            "forcemerge": {
                                "max_num_segments": 1
                            }
                        }
                    },
                    "delete": {
                        "min_age": "395d"
                    }
                }
            }
        }'
    
    log_success "Política ILM criada"
}

# Criar template de índice
create_index_template() {
    log_info "Criando template de índice..."
    
    curl -X PUT "${ELASTIC_URL}/_index_template/cgnat-logs" \
        -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "index_patterns": ["cgnat-logs-*"],
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    "index.refresh_interval": "5s",
                    "index.codec": "best_compression",
                    "index.lifecycle.name": "cgnat-policy",
                    "index.lifecycle.rollover_alias": "cgnat-logs"
                },
                "mappings": {
                    "properties": {
                        "@timestamp": { "type": "date" },
                        "event": {
                            "properties": {
                                "category": { "type": "keyword" },
                                "kind": { "type": "keyword" },
                                "dataset": { "type": "keyword" },
                                "timezone": { "type": "keyword" }
                            }
                        },
                        "source": {
                            "properties": {
                                "ip": { "type": "ip" },
                                "port": { "type": "integer" },
                                "nat": {
                                    "properties": {
                                        "ip": { "type": "ip" },
                                        "port": { "type": "integer" }
                                    }
                                }
                            }
                        },
                        "destination": {
                            "properties": {
                                "ip": { "type": "ip" },
                                "port": { "type": "integer" }
                            }
                        },
                        "network": {
                            "properties": {
                                "transport": { "type": "keyword" },
                                "iana_number": { "type": "integer" }
                            }
                        },
                        "observer": {
                            "properties": {
                                "hostname": { "type": "keyword" },
                                "vendor": { "type": "keyword" },
                                "product": { "type": "keyword" },
                                "type": { "type": "keyword" }
                            }
                        },
                        "user": {
                            "properties": {
                                "name": { "type": "keyword" }
                            }
                        },
                        "cgnat": {
                            "properties": {
                                "session": {
                                    "properties": {
                                        "id": { "type": "keyword" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }'
    
    log_success "Template de índice criado"
}

# Criar índice inicial
create_initial_index() {
    log_info "Criando índice inicial..."
    
    TODAY=$(date +%Y.%m.%d)
    
    curl -X PUT "${ELASTIC_URL}/cgnat-logs-${TODAY}-000001" \
        -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "aliases": {
                "cgnat-logs": {
                    "is_write_index": true
                }
            }
        }'
    
    log_success "Índice inicial criado"
}

# Configurar repositório de snapshot local
create_snapshot_repository() {
    log_info "Configurando repositório de snapshot..."
    
    # Repositório local
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
    create_ilm_policy
    create_index_template
    create_initial_index
    create_snapshot_repository
    
    log_success "Configuração do Elasticsearch concluída!"
    log_info "Elasticsearch está pronto para receber logs NAT/CGNAT"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi