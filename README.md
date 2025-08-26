# Portal de Logs NAT/CGNAT

Portal completo para armazenamento, pesquisa e relatórios de logs NAT/CGNAT em conformidade com a legislação brasileira.

## 🎯 Características

- **Conformidade Legal**: Retenção de 13 meses conforme marcos normativos brasileiros
- **Busca Avançada**: Por IP público/privado, porta e intervalos de tempo
- **Relatórios Oficiais**: PDF com hash SHA-256 e CSV para anexos
- **Dashboard em Tempo Real**: Métricas de ingestão e top IPs/portas
- **RBAC**: Controle de acesso por perfis (Admin, Operação, Jurídico)
- **Auditoria Completa**: Log de todas as ações e acessos
- **Backup Automático**: Local e offsite com retenção configurável

## 🏗️ Arquitetura

```
[Equipamentos CGNAT/Firewall] 
    ↓ Syslog (TCP/UDP/TLS)
[Logstash] → Parse/Normalize
    ↓ 
[Elasticsearch] → Indexação/Retenção
    ↓
[Portal Web] → Interface/Relatórios
[Kibana] → Dashboards avançados
[MinIO] → Backup offsite
```

## 📋 Requisitos

- **SO**: Debian 12 (Bookworm)
- **RAM**: Mínimo 4GB (recomendado 8GB+)
- **Disco**: Mínimo 50GB (dimensionar conforme volume de logs)
- **CPU**: 2 cores (recomendado 4+)
- **Rede**: Portas 5514 (syslog), 7880 (portal), 5601 (kibana)

## 🚀 Instalação Rápida

### 1. Executar Script de Instalação

```bash
# Download e execução do script
curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

### 2. Se houver problemas, executar correção

```bash
# Script de correção
curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/fix-install.sh -o fix-install.sh
chmod +x fix-install.sh
sudo ./fix-install.sh
```

### 3. Verificar Instalação

```bash
# Verificar status dos containers
cd /opt/cgnat-portal && docker compose ps

# Ver logs
docker compose logs -f

# Testar conectividade
curl http://localhost:9200/_cluster/health
curl http://localhost:7880
```

## 🔧 Configuração

### Equipamentos CGNAT

Configure seus equipamentos para enviar logs via syslog:

**Hillstone CGNAT:**
```
# Configurar syslog server
syslog-server 192.168.1.100 port 5514 protocol tcp
syslog-server enable
```

**MikroTik RouterOS:**
```
/system logging action
add name=cgnat-server target=remote remote=192.168.1.100:5514

/system logging
add topics=firewall,info action=cgnat-server
```

**Cisco ASA:**
```
logging host 192.168.1.100:5514
logging trap informational
```

### Formatos de Log Suportados

O sistema suporta múltiplos formatos:

1. **Hillstone**: `orig=IP:porta trans=IP:porta dst=IP:porta proto=6`
2. **MikroTik**: `srcnat: src=IP:porta to=IP:porta dst=IP:porta proto=tcp`
3. **Genérico**: Formato key=value configurável

## 📊 Uso

### Dashboard

Acesse `http://seu-servidor:7880` para:
- Visualizar métricas em tempo real
- Monitorar top IPs e portas
- Verificar status de ingestão
- Acompanhar erros de parse

### Busca Avançada

1. **Por IP Público + Porta**: Descobrir quem estava usando um IP:porta específico
2. **Por IP Privado**: Rastrear atividade de um cliente específico
3. **Por Intervalo de Tempo**: Logs em período específico

### Relatórios

**PDF (até 100 linhas):**
- Cabeçalho institucional
- Critérios de busca
- Hash SHA-256 para integridade
- Carimbo temporal UTC

**CSV (completo):**
- Todos os registros encontrados
- Metadados incluídos
- Hash de verificação

## 🔒 Segurança

### Controle de Acesso

- **Admin**: Acesso total, configurações
- **Operação**: Busca e relatórios
- **Jurídico**: Apenas visualização e relatórios

### Auditoria

Todas as ações são registradas:
- Logins/logouts
- Buscas realizadas
- Relatórios gerados
- IP e user-agent do usuário

### Backup

**Automático:**
- Diário: 7 dias de retenção
- Semanal: 5 semanas de retenção  
- Mensal: 13 meses de retenção

**Destinos:**
- Local: `/opt/cgnat-portal/backups`
- Offsite: MinIO S3-compatible

## 📈 Monitoramento

### Health Checks

Script automático verifica:
- Status do Elasticsearch
- Status do Kibana
- Status do Portal
- Uso de disco
- Taxa de ingestão

### Logs do Sistema

```bash
# Logs do portal
tail -f /var/log/cgnat-portal/health.log

# Logs de backup
tail -f /var/log/cgnat-portal/backup.log

# Logs do Docker
cd /opt/cgnat-portal && docker compose logs -f
```

### Alertas

Configure webhooks para Slack/Teams em caso de:
- Falha de ingestão > 5 minutos
- Uso de disco > 80%
- Falha de backup
- Erros de parse > 100/hora

## 🛠️ Manutenção

### Backup Manual

```bash
# Criar snapshot
/opt/cgnat-portal/scripts/backup.sh

# Listar snapshots
curl -X GET "localhost:9200/_snapshot/local_backup/_all"

# Restaurar snapshot
curl -X POST "localhost:9200/_snapshot/local_backup/snapshot_name/_restore"
```

### Limpeza de Índices

```bash
# Verificar índices antigos
curl -X GET "localhost:9200/_cat/indices/cgnat-logs-*?v&s=index"

# Deletar índice específico (cuidado!)
curl -X DELETE "localhost:9200/cgnat-logs-2023.01.01"
```

### Atualização

```bash
cd /opt/cgnat-portal
curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/docker-compose.yml -o docker-compose.yml
docker compose down
docker compose up -d
```

## 🐛 Troubleshooting

### Elasticsearch não inicia

```bash
# Verificar logs
cd /opt/cgnat-portal && docker compose logs elasticsearch

# Verificar permissões
sudo chown -R 1000:1000 /opt/cgnat-portal/elasticsearch

# Verificar memória
free -h
```

### Logs não aparecem

```bash
# Verificar Logstash
cd /opt/cgnat-portal && docker compose logs logstash

# Testar conectividade syslog
echo "test message" | nc localhost 5514

# Testar com script
/opt/cgnat-portal/scripts/test-syslog.sh localhost 5514
```

### Portal não carrega

```bash
# Verificar container
cd /opt/cgnat-portal && docker compose ps portal

# Verificar logs
docker compose logs portal

# Verificar conectividade
curl -v http://localhost:7880
```

## 🧪 Teste de Logs

```bash
# Testar envio de logs
/opt/cgnat-portal/scripts/test-syslog.sh SEU_IP 5514

# Verificar no Kibana
# Acesse http://SEU_IP:5601
# Vá em "Discover" e procure por índice "cgnat-logs-*"
```

## 📞 Suporte

Para suporte técnico:
- **Issues**: https://github.com/theangelz/dashboard-em-tempo-real/issues
- **Documentação**: Este README

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## ⚖️ Conformidade Legal

**IMPORTANTE**: Esta solução implementa requisitos técnicos de guarda e segurança de registros. Políticas internas (acesso, cadeia de custódia, retenção estendida, resposta a ofícios) devem ser validadas pelo jurídico do provedor.

O sistema atende aos marcos normativos brasileiros para guarda de registros de conexão, incluindo:
- Retenção mínima de 13 meses
- Controles de acesso adequados
- Trilha de auditoria completa
- Integridade dos dados (hash SHA-256)

## 🎯 Comandos Rápidos

```bash
# Instalação completa
curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/install.sh | sudo bash

# Correção se houver problemas
curl -fsSL https://raw.githubusercontent.com/theangelz/dashboard-em-tempo-real/main/fix-install.sh | sudo bash

# Ver status
cd /opt/cgnat-portal && docker compose ps

# Testar logs
/opt/cgnat-portal/scripts/test-syslog.sh $(hostname -I | awk '{print $1}') 5514