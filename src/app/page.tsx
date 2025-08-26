import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Shield, Search, FileText, BarChart3, Clock, Lock } from "lucide-react";
import Link from "next/link";

export default function Home() {
  const plans = [
    {
      title: "Pequeno Porte",
      range: "0 - 1.000 assinantes",
      features: ["Retenção 13 meses", "Relatórios básicos", "Suporte email"],
      price: "Consulte"
    },
    {
      title: "Médio Porte",
      range: "1.001 - 3.000 assinantes", 
      features: ["Retenção 13 meses", "Relatórios avançados", "Suporte prioritário", "Backup automático"],
      price: "Consulte",
      popular: true
    },
    {
      title: "Grande Porte",
      range: "3.001 - 10.000 assinantes",
      features: ["Retenção 13 meses", "Relatórios completos", "Suporte 24/7", "Backup redundante", "SLA 99.9%"],
      price: "Consulte"
    }
  ];

  const features = [
    {
      icon: Shield,
      title: "Conformidade Legal",
      description: "Atende marcos normativos brasileiros com retenção mínima de 13 meses"
    },
    {
      icon: Search,
      title: "Busca Avançada",
      description: "Pesquise por IP público, porta, IP privado e intervalos de tempo"
    },
    {
      icon: FileText,
      title: "Relatórios Oficiais",
      description: "Gere relatórios em PDF e CSV com hash SHA-256 e carimbo temporal"
    },
    {
      icon: BarChart3,
      title: "Dashboard em Tempo Real",
      description: "Monitore taxa de eventos, top IPs e status de ingestão"
    },
    {
      icon: Clock,
      title: "Retenção Automática",
      description: "Política ILM com rollover diário e retenção de 13 meses"
    },
    {
      icon: Lock,
      title: "Segurança Avançada",
      description: "RBAC, auditoria completa, TLS e controle de acesso"
    }
  ];

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b bg-white">
        <div className="container mx-auto px-4 py-4 flex justify-between items-center">
          <div className="flex items-center space-x-2">
            <Shield className="h-8 w-8 text-blue-600" />
            <span className="text-xl font-bold">CGNAT Portal</span>
          </div>
          <div className="space-x-4">
            <Link href="/login">
              <Button variant="outline">Entrar</Button>
            </Link>
            <Link href="/register">
              <Button>Cadastrar</Button>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="bg-gradient-to-r from-blue-600 to-blue-800 text-white py-20">
        <div className="container mx-auto px-4 text-center">
          <h1 className="text-4xl md:text-6xl font-bold mb-6">
            Portal de Logs NAT/CGNAT
          </h1>
          <p className="text-xl md:text-2xl mb-8 max-w-3xl mx-auto">
            Solução completa para armazenamento, pesquisa e relatórios de logs NAT/CGNAT 
            em conformidade com a legislação brasileira
          </p>
          <div className="space-x-4">
            <Link href="/register">
              <Button size="lg" className="bg-white text-blue-600 hover:bg-gray-100">
                Começar Agora
              </Button>
            </Link>
            <Link href="/demo">
              <Button size="lg" variant="outline" className="border-white text-white hover:bg-white hover:text-blue-600">
                Ver Demo
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-20 bg-gray-50">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold mb-4">
              Recursos Principais
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Tudo que você precisa para gerenciar logs NAT/CGNAT de forma segura e eficiente
            </p>
          </div>
          
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <Card key={index} className="text-center">
                <CardHeader>
                  <feature.icon className="h-12 w-12 text-blue-600 mx-auto mb-4" />
                  <CardTitle>{feature.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <CardDescription className="text-base">
                    {feature.description}
                  </CardDescription>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Plans */}
      <section className="py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold mb-4">
              Planos Disponíveis
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Escolha o plano ideal para o porte do seu provedor
            </p>
          </div>
          
          <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {plans.map((plan, index) => (
              <Card key={index} className={`relative ${plan.popular ? 'border-blue-500 shadow-lg' : ''}`}>
                {plan.popular && (
                  <Badge className="absolute -top-3 left-1/2 transform -translate-x-1/2 bg-blue-600">
                    Mais Popular
                  </Badge>
                )}
                <CardHeader className="text-center">
                  <CardTitle className="text-2xl">{plan.title}</CardTitle>
                  <CardDescription className="text-lg font-medium text-blue-600">
                    {plan.range}
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="text-center">
                    <span className="text-3xl font-bold">{plan.price}</span>
                  </div>
                  <ul className="space-y-2">
                    {plan.features.map((feature, featureIndex) => (
                      <li key={featureIndex} className="flex items-center">
                        <Shield className="h-4 w-4 text-green-500 mr-2" />
                        {feature}
                      </li>
                    ))}
                  </ul>
                  <Button className="w-full" variant={plan.popular ? "default" : "outline"}>
                    Contratar
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="bg-blue-600 text-white py-16">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Pronto para começar?
          </h2>
          <p className="text-xl mb-8 max-w-2xl mx-auto">
            Configure seu portal de logs em minutos e garanta conformidade total com a legislação
          </p>
          <Link href="/register">
            <Button size="lg" className="bg-white text-blue-600 hover:bg-gray-100">
              Criar Conta Gratuita
            </Button>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-12">
        <div className="container mx-auto px-4">
          <div className="grid md:grid-cols-4 gap-8">
            <div>
              <div className="flex items-center space-x-2 mb-4">
                <Shield className="h-6 w-6" />
                <span className="text-lg font-bold">CGNAT Portal</span>
              </div>
              <p className="text-gray-400">
                Solução completa para gerenciamento de logs NAT/CGNAT
              </p>
            </div>
            <div>
              <h3 className="font-semibold mb-4">Produto</h3>
              <ul className="space-y-2 text-gray-400">
                <li>Recursos</li>
                <li>Planos</li>
                <li>Documentação</li>
                <li>API</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold mb-4">Suporte</h3>
              <ul className="space-y-2 text-gray-400">
                <li>Central de Ajuda</li>
                <li>Contato</li>
                <li>Status</li>
                <li>Comunidade</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold mb-4">Legal</h3>
              <ul className="space-y-2 text-gray-400">
                <li>Privacidade</li>
                <li>Termos</li>
                <li>Conformidade</li>
                <li>Segurança</li>
              </ul>
            </div>
          </div>
          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
            <p>&copy; 2024 CGNAT Portal. Todos os direitos reservados.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}