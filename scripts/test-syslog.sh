#!/bin/bash

# Script para testar envio de logs syslog para o portal

SERVER="${1:-localhost}"
PORT="${2:-5514}"

echo "Testando envio de logs para ${SERVER}:${PORT}"

# Logs de teste em diferentes formatos
LOGS=(
    # Hillstone CGNAT
    "<134>Jan 15 14:32:15 cgnat-fw hillstone: orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17 sess=abc123 user=user@provedor.com"
    
    # MikroTik
    "<134>Jan 15 14:32:16 mikrotik-rb routeros: srcnat: src=100.64.1.46:54322 to=177.45.123.46:12346 dst=1.1.1.1:53 proto=udp user=user2@provedor.com"
    
    # Genérico key=value
    "<134>Jan 15 14:32:17 firewall-01 cgnat: orig=100.64.1.47:54323 trans=177.45.123.47:12347 dst=8.8.4.4:53 proto=17"
    
    # Cisco ASA
    "<134>Jan 15 14:32:18 asa-01 asa: Built outbound UDP translation from inside:100.64.1.48/54324 to outside:177.45.123.48/12348"
)

for log in "${LOGS[@]}"; do
    echo "Enviando: $log"
    echo "$log" | nc -w1 "$SERVER" "$PORT"
    sleep 1
done

echo "Teste concluído. Verifique os logs no Kibana em http://${SERVER}:5601"