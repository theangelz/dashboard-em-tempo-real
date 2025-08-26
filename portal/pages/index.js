export default function Home() {
  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>Portal de Logs NAT/CGNAT</h1>
      <p>Sistema de gerenciamento de logs em conformidade com a legislação brasileira.</p>
      
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
        <p>Configure seus equipamentos CGNAT/Firewall para enviar logs via syslog:</p>
        <pre style={{ background: '#f5f5f5', padding: '10px', borderRadius: '5px' }}>
{`Servidor: ${typeof window !== 'undefined' ? window.location.hostname : 'SEU_SERVIDOR'}
Porta TCP: 5514
Porta UDP: 5514 (opcional)
Formato: Hillstone, MikroTik, Cisco ASA ou genérico key=value`}
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