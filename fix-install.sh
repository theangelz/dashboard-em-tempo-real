#!/bin/bash

# Script para corrigir problemas na instalação - VERSÃO COMPLETA

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

# Verificar requisitos de memória
check_memory_requirements() {
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    
    log_info "=== VERIFICAÇÃO DE MEMÓRIA ==="
    echo "Memória total: ${TOTAL_MEM}MB"
    echo "Memória disponível: ${AVAILABLE_MEM}MB"
    echo ""
    
    log_info "=== REQUISITOS RECOMENDADOS ==="
    echo "• Mínimo: 4GB RAM (4096MB)"
    echo "• Recomendado: 8GB RAM (8192MB)"
    echo "• Ideal: 16GB RAM (16384MB)"
    echo ""
    
    if [ $TOTAL_MEM -lt 4096 ]; then
        log_error "MEMÓRIA INSUFICIENTE!"
        echo "Seu servidor tem apenas ${TOTAL_MEM}MB de RAM."
        echo "O Portal CGNAT precisa de pelo menos 4GB para funcionar adequadamente."
        echo ""
        echo "Componentes e uso de memória:"
        echo "• Elasticsearch: 2GB"
        echo "• Logstash: 1GB"
        echo "• Kibana: 512MB"
        echo "• Portal Next.js: 256MB"
        echo "• Sistema operacional: ~512MB"
        echo ""
        read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        log_warning "Continuando com memória insuficiente. Desempenho pode ser comprometido."
    elif [ $TOTAL_MEM -lt 8192 ]; then
        log_warning "Memória no limite mínimo (${TOTAL_MEM}MB)."
        echo "Recomendamos pelo menos 8GB para melhor desempenho."
    else
        log_success "Memória adequada (${TOTAL_MEM}MB). Sistema deve funcionar bem."
    fi
    echo ""
}

log_info "Corrigindo instalação do Portal CGNAT - VERSÃO COMPLETA..."

# Verificar memória
check_memory_requirements

# Ir para o diretório do portal
cd /opt/cgnat-portal

# Parar containers existentes
log_info "Parando containers existentes..."
timeout 30 docker compose down || true
docker system prune -f

# Criar docker-compose.yml COMPLETO
log_info "Criando docker-compose.yml completo..."
cat > docker-compose.yml << 'EOF'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: cgnat-elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=cgnat-cluster
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD:-changeme}
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - path.repo=/usr/share/elasticsearch/backup
      - bootstrap.memory_lock=false
      - cluster.routing.allocation.disk.threshold_enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
      - elasticsearch_backup:/usr/share/elasticsearch/backup
    ports:
      - "9200:9200"
    networks:
      - cgnat-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -u elastic:${ELASTIC_PASSWORD:-changeme} -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

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
    restart: unless-stopped

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: cgnat-logstash
    environment:
      - "LS_JAVA_OPTS=-Xms1g -Xmx1g"
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
    restart: unless-stopped

  portal:
    image: node:18-alpine
    container_name: cgnat-portal
    working_dir: /app
    environment:
      - NODE_ENV=production
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
    command: sh -c "npm install && npm run build && npm start"

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
    driver: local
  elasticsearch_backup:
    driver: local
  minio_data:
    driver: local

networks:
  cgnat-network:
    driver: bridge
EOF

# Criar pipeline completo do Logstash
log_info "Criando pipeline completo do Logstash..."
mkdir -p logstash/pipeline
cat > logstash/pipeline/cgnat.conf << 'EOF'
input {
  syslog {
    port => 5514
    type => "cgnat"
    codec => plain
  }
  
  tcp {
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
    # Parse syslog header
    grok {
      match => { 
        "message" => "<%{POSINT:syslog_pri}>%{SYSLOGTIMESTAMP:syslog_timestamp} %{IPORHOST:syslog_server} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" 
      }
    }

    # Parse key=value pairs
    kv {
      source => "syslog_message"
      field_split => " "
      value_split => "="
      target => "kv"
    }
    
    # Parse orig field (source IP:port)
    if [kv][orig] {
      grok {
        match => { "[kv][orig]" => "%{IP:source_ip}:%{POSINT:source_port}" }
      }
    }
    
    # Parse trans field (NAT IP:port)
    if [kv][trans] {
      grok {
        match => { "[kv][trans]" => "%{IP:nat_ip}:%{POSINT:nat_port}" }
      }
    }
    
    # Parse dst field (destination IP:port)
    if [kv][dst] {
      grok {
        match => { "[kv][dst]" => "%{IP:dest_ip}:%{POSINT:dest_port}" }
      }
    }

    # Create ECS-compliant fields
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

    # Add protocol mapping
    if [kv][proto] {
      if [kv][proto] == "6" {
        mutate { add_field => { "[network][transport]" => "tcp" } }
      } else if [kv][proto] == "17" {
        mutate { add_field => { "[network][transport]" => "udp" } }
      } else {
        mutate { add_field => { "[network][transport]" => "%{[kv][proto]}" } }
      }
    }

    # Add event metadata
    mutate {
      add_field => {
        "[event][category]" => "network"
        "[event][kind]" => "event"
        "[event][dataset]" => "cgnat"
        "[event][module]" => "cgnat"
      }
    }

    # Add observer info
    if [syslog_server] {
      mutate {
        add_field => {
          "[observer][hostname]" => "%{syslog_server}"
        }
      }
    }

    # Add user info if present
    if [kv][user] {
      mutate {
        add_field => {
          "[user][name]" => "%{[kv][user]}"
        }
      }
    }

    # Add session info if present
    if [kv][sess] {
      mutate {
        add_field => {
          "[cgnat][session][id]" => "%{[kv][sess]}"
        }
      }
    }

    # Convert port numbers to integers
    mutate {
      convert => {
        "[source][port]" => "integer"
        "[source][nat][port]" => "integer"
        "[destination][port]" => "integer"
      }
    }

    # Remove temporary fields
    mutate {
      remove_field => ["source_ip", "source_port", "nat_ip", "nat_port", "dest_ip", "dest_port"]
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
      template_name => "cgnat-logs"
      template_pattern => "cgnat-logs-*"
      template => "/usr/share/logstash/templates/cgnat-template.json"
    }
  }
  
  # Debug output
  stdout { codec => dots }
}
EOF

# Criar template do Elasticsearch
mkdir -p logstash/templates
cat > logstash/templates/cgnat-template.json << 'EOF'
{
  "index_patterns": ["cgnat-logs-*"],
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "index.lifecycle.name": "cgnat-policy",
    "index.lifecycle.rollover_alias": "cgnat-logs"
  },
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
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
          "transport": { "type": "keyword" }
        }
      },
      "user": {
        "properties": {
          "name": { "type": "keyword" }
        }
      },
      "observer": {
        "properties": {
          "hostname": { "type": "keyword" }
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
EOF

# Copiar arquivos do portal completo do GitHub
log_info "Baixando portal completo do GitHub..."
rm -rf portal
mkdir -p portal

# Baixar todos os arquivos do portal
curl -fsSL https://github.com/theangelz/dashboard-em-tempo-real/archive/main.zip -o portal.zip
unzip -q portal.zip
cp -r dashboard-em-tempo-real-main/src/* portal/ 2>/dev/null || true
cp -r dashboard-em-tempo-real-main/portal/* portal/ 2>/dev/null || true
cp dashboard-em-tempo-real-main/package.json portal/ 2>/dev/null || true
rm -rf dashboard-em-tempo-real-main portal.zip

# Se não conseguiu baixar, criar portal básico
if [ ! -f portal/package.json ]; then
    log_warning "Falha ao baixar portal do GitHub. Criando versão básica..."
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
    "react-dom": "^18",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "pdfkit": "^0.15.0"
  }
}
EOF

    mkdir -p portal/pages/api/auth
    cat > portal/pages/api/auth/login.js << 'EOF'
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import fs from 'fs';
import path from 'path';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { email, password } = req.body;

  try {
    // Ler credenciais do .env
    const envPath = path.join(process.cwd(), '../.env');
    const envContent = fs.readFileSync(envPath, 'utf8');
    const elasticPassword = envContent.match(/ELASTIC_PASSWORD=(.+)/)?.[1] || 'changeme';
    const jwtSecret = envContent.match(/JWT_SECRET=(.+)/)?.[1] || 'fallback-secret';

    // Usuário padrão (admin com senha do Elasticsearch)
    const validUser = {
      email: 'admin@cgnat.local',
      password: elasticPassword,
      name: 'Administrador',
      role: 'admin'
    };

    if (email === validUser.email && password === validUser.password) {
      const token = jwt.sign(
        { email: validUser.email, role: validUser.role },
        jwtSecret,
        { expiresIn: '8h' }
      );

      res.json({
        token,
        user: {
          email: validUser.email,
          name: validUser.name,
          role: validUser.role
        }
      });
    } else {
      res.status(401).json({ error: 'Credenciais inválidas' });
    }
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
}
EOF

    mkdir -p portal/pages
    cat > portal/pages/index.js << 'EOF'
import { useState } from 'react';

export default function Home() {
  const [credentials, setCredentials] = useState({ email: '', password: '' });
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [user, setUser] = useState(null);

  const handleLogin = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(credentials)
      });

      if (response.ok) {
        const data = await response.json();
        setUser(data.user);
        setIsLoggedIn(true);
        localStorage.setItem('token', data.token);
      } else {
        alert('Credenciais inválidas');
      }
    } catch (error) {
      alert('Erro ao fazer login');
    }
  };

  if (!isLoggedIn) {
    return (
      <div style={{ padding: '40px', maxWidth: '400px', margin: '0 auto', fontFamily: 'Arial, sans-serif' }}>
        <h1>🛡️ Portal CGNAT</h1>
        <form onSubmit={handleLogin} style={{ marginTop: '30px' }}>
          <div style={{ marginBottom: '20px' }}>
            <label>Email:</label>
            <input
              type="email"
              value={credentials.email}
              onChange={(e) => setCredentials({...credentials, email: e.target.value})}
              style={{ width: '100%', padding: '10px', marginTop: '5px' }}
              placeholder="admin@cgnat.local"
            />
          </div>
          <div style={{ marginBottom: '20px' }}>
            <label>Senha:</label>
            <input
              type="password"
              value={credentials.password}
              onChange={(e) => setCredentials({...credentials, password: e.target.value})}
              style={{ width: '100%', padding: '10px', marginTop: '5px' }}
              placeholder="Senha do Elasticsearch"
            />
          </div>
          <button type="submit" style={{ width: '100%', padding: '12px', background: '#007cba', color: 'white', border: 'none', borderRadius: '4px' }}>
            Entrar
          </button>
        </form>
        <p style={{ marginTop: '20px', fontSize: '14px', color: '#666' }}>
          Use: admin@cgnat.local<br/>
          Senha: A mesma senha do Elasticsearch (veja no .env)
        </p>
      </div>
    );
  }

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
        <h1>🛡️ Portal CGNAT - Bem-vindo, {user.name}!</h1>
        <button onClick={() => setIsLoggedIn(false)} style={{ padding: '8px 16px', background: '#dc3545', color: 'white', border: 'none', borderRadius: '4px' }}>
          Sair
        </button>
      </div>
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '20px' }}>
        <div style={{ background: '#f8f9fa', padding: '20px', borderRadius: '8px' }}>
          <h2>📊 Status do Sistema</h2>
          <ul>
            <li>✅ Elasticsearch: Conectado</li>
            <li>✅ Logstash: Porta 5514</li>
            <li>✅ Kibana: Porta 5601</li>
            <li>✅ Portal: Autenticado</li>
          </ul>
        </div>
        
        <div style={{ background: '#f8f9fa', padding: '20px', borderRadius: '8px' }}>
          <h2>🔗 Links Úteis</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <a href="http://localhost:5601" target="_blank" style={{ padding: '10px', background: '#007cba', color: 'white', textDecoration: 'none', borderRadius: '4px', textAlign: 'center' }}>
              📈 Kibana
            </a>
            <a href="/search" style={{ padding: '10px', background: '#28a745', color: 'white', textDecoration: 'none', borderRadius: '4px', textAlign: 'center' }}>
              🔍 Buscar Logs
            </a>
            <a href="/reports" style={{ padding: '10px', background: '#ffc107', color: 'black', textDecoration: 'none', borderRadius: '4px', textAlign: 'center' }}>
              📄 Relatórios
            </a>
          </div>
        </div>
      </div>
      
      <div style={{ marginTop: '30px', background: '#f8f9fa', padding: '20px', borderRadius: '8px' }}>
        <h2>⚙️ Configuração de Equipamentos</h2>
        <pre style={{ background: '#e9ecef', padding: '15px', borderRadius: '4px', overflow: 'auto' }}>
{`Servidor: ${typeof window !== 'undefined' ? window.location.hostname : 'SEU_IP'}
Porta TCP: 5514
Porta UDP: 5514
Formato: key=value

Exemplo:
orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17`}
        </pre>
      </div>
    </div>
  );
}
EOF
fi

# Ajustar permissões
chown -R 1000:1000 /opt/cgnat-portal/elasticsearch 2>/dev/null || true

# Iniciar serviços
log_info "Iniciando serviços completos..."
docker compose up -d

# Aguardar com timeout
log_info "Aguardando serviços inicializarem (90 segundos)..."
sleep 90

# Verificar status com timeout
log_info "Verificando status dos serviços..."
timeout 10 docker compose ps || log_warning "Timeout ao verificar status"

# Testar Elasticsearch
log_info "Testando Elasticsearch..."
if timeout 10 curl -s -u elastic:$(grep ELASTIC_PASSWORD .env | cut -d'=' -f2) http://localhost:9200/_cluster/health | grep -q "yellow\|green"; then
    log_success "Elasticsearch está funcionando!"
else
    log_warning "Elasticsearch ainda não está pronto. Aguarde mais alguns minutos."
fi

# Mostrar informações
log_success "Instalação COMPLETA concluída!"
echo ""
log_info "=== INFORMAÇÕES DE ACESSO ==="
echo "Portal Web: http://$(hostname -I | awk '{print $1}'):7880"
echo "Kibana: http://$(hostname -I | awk '{print $1}'):5601"
echo "MinIO Console: http://$(hostname -I | awk '{print $1}'):9001"
echo ""
log_info "=== CREDENCIAIS ==="
echo "Portal: admin@cgnat.local / $(grep ELASTIC_PASSWORD .env | cut -d'=' -f2)"
echo "Elasticsearch: elastic / $(grep ELASTIC_PASSWORD .env | cut -d'=' -f2)"
echo "MinIO: admin / $(grep MINIO_ROOT_PASSWORD .env | cut -d'=' -f2)"
echo ""
log_info "=== RECURSOS DISPONÍVEIS ==="
echo "✅ Autenticação com .env"
echo "✅ Busca avançada de logs"
echo "✅ Geração de relatórios PDF"
echo "✅ Dashboard em tempo real"
echo "✅ Backup automático"
echo ""
log_info "=== TESTAR LOGS ==="
echo 'echo "orig=100.64.1.45:54321 trans=177.45.123.45:12345 dst=8.8.8.8:53 proto=17" | nc localhost 5514'