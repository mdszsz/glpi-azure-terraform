**GLPI no Azure com Terraform**  
Migração do GLPI de produção de um VPS na Locaweb para o Microsoft Azure, com **100% da infraestrutura em Terraform**, banco de dados privado, backup e monitoramento nativos e deploy por pipeline com autenticação  **OIDC, sem nenhum segredo de longa duração**.  
**Resultado**  
| | |  
|-|-|  
| **Antes (Locaweb)** | **Depois (Azure)** |   
| VPS Ubuntu 20.04 (fim do suporte padrão) | VM Ubuntu 24.04 LTS |   
| MariaDB 10.3 (fim de vida) no mesmo servidor | MySQL Flexible Server 8.0 gerenciado, sem IP público |   
| GLPI 10.0.27 | GLPI 10.0.28 (última versão da linha 10) |   
| Configuração manual | Infraestrutura como código, revisada por pull request |   
| Sem backup automatizado da VM | Backup diário da VM (14 dias) + backup nativo do MySQL (14 dias) |   
| Sem monitoramento | Log Analytics, métricas, syslog, logs do MySQL e alertas por e-mail |   
| Ações automáticas do GLPI dependiam de acesso web | Cron dedicado |   
   
**Arquitetura**  
| | | |  
|-|-|-|  
| **Componente** | **Recurso** | **Detalhe** |   
| Rede | vnet-prd-web-eus-001 (10.10.0.0/16) | snet-prd-app 10.10.1.0/24 e snet-prd-db 10.10.2.0/24 (delegada) |   
| Firewall | nsg-prd-web-eus-001 | 443 e 80 abertos; SSH (22) só do IP de administração |   
| Aplicação | vm-prd-web-eus-001 (Standard_B2s) | Apache 2.4, PHP 8.3, GLPI 10.0.28, configurada por cloud-init |   
| Banco | db-prd-web-eus-mszsz-001 (B_Standard_B1ms) | MySQL 8.0, VNet Integration, Private DNS, TLS obrigatório |   
| DNS | glpi.mszsz.com.br | Registro alias para o IP público + CAA restrito ao Let's Encrypt |   
| TLS | Let's Encrypt (certbot) | Renovação automática, HSTS e cabeçalhos de segurança |   
| Observabilidade | log-prd-web-eus-001 | Azure Monitor Agent + regra de coleta, logs lentos e de auditoria do MySQL |   
| Alertas | 4 alertas de métrica | CPU da VM, disponibilidade da VM, CPU e disco do MySQL |   
| Backup | rsv-prd-web-eus-001 | Diário às 02:00 (Brasília), 14 diários + 4 semanais |   
   
**Decisões técnicas**  
- **VNet Integration em vez de Private Endpoint no MySQL.** No Flexible Server é um ou outro. A subnet delegada com Private DNS Zone é mais simples e não tem custo extra.  
- **OIDC no GitHub Actions.** O pipeline entra no Azure com tokens de curta duração emitidos pelo GitHub. Não existe client secret armazenado em lugar nenhum.  
- **State remoto sem chave de acesso.** O Storage Account do state tem allow_shared_key_access = false, versionamento e soft delete. O acesso é só por Entra ID (RBAC).  
- **State e DNS fora do ciclo de vida do projeto.** O state fica em rg-tfstate-eus-001 e a zona DNS em rg-recursos-permanentes, lida via data source. Um terraform destroy nunca apaga nenhum dos dois.  
- **Dados do GLPI fora da pasta web.** Configuração em /etc/glpi, arquivos em /var/lib/glpi e logs em /var/log/glpi, como recomenda a documentação oficial.  
- **Usuário de banco dedicado.** O GLPI usa um usuário glpi com acesso só ao próprio banco e restrito à subnet da aplicação, nunca o admin do servidor.  
**Pipeline**  
branch ──► pull request ──► plan (fmt, validate, Checkov, plan) ──► merge ──► plan ──► apply (environment: production)  
   
- plan roda em todo pull request que altera infra/ ou scripts/.  
- apply roda só na main, a partir do plano salvo no mesmo pipeline.  
- O Terraform tem a mesma versão (1.17.1) no PC e no pipeline, e os providers estão fixados pelo .terraform.lock.hcl.  
**Segurança**  
Análise estática com **Checkov** a cada execução. As exceções aceitas estão documentadas no próprio código com #checkov:skip e justificativa:  
| | |  
|-|-|  
| **Regra** | **Justificativa** |   
| CKV_AZURE_160 | Porta 80 necessária para o desafio HTTP-01 do Let's Encrypt e o redirect para HTTPS |   
| CKV_AZURE_119 | VM única exposta por IP público com NSG restrito (Application Gateway no roadmap) |   
| CKV_AZURE_50 | Extensão do Azure Monitor Agent é necessária |   
| CKV2_AZURE_56 / CKV_AZURE_53 | VNet Integration já torna o MySQL privado |   
| CKV_AZURE_94 | Backup geo-redundante descartado por custo |   
| CKV2_AZURE_35 | Identidade gerenciada só é exigida para criptografia com chave própria |   
| CKV2_AZURE_31 | Subnet delegada ao MySQL; NSG dedicado no roadmap |   
   
Outras medidas: SSH só por chave e só do IP de administração, fail2ban, unattended-upgrades, TLS verificado entre a aplicação e o banco, cookies Secure, HttpOnly e SameSite, HSTS, e varredura do histórico com gitleaks antes da publicação.  
**Observabilidade**  
Consultas KQL usadas no Log Analytics:  
// Saúde do agente  
 Heartbeat  
 | summarize último = max(TimeGenerated) by Computer  
   
 // CPU, memória e disco da VM  
 Perf  
 | where TimeGenerated > ago(2h)  
 | summarize avg(CounterValue) by CounterName, bin(TimeGenerated, 5m)  
 | render timechart  
   
 // Logs do MySQL por categoria  
 AzureDiagnostics  
 | where ResourceProvider == "MICROSOFT.DBFORMYSQL"  
 | summarize count() by Category  
   
**Estrutura**  
.  
 ├── .github/workflows/terraform.yml   # pipeline (plan em PR, apply na main)  
 ├── bootstrap/backend.sh              # cria o state remoto (executado uma vez)  
 ├── docs/arquitetura.png  
 ├── infra/  
 │   ├── providers.tf    # providers e backend  
 │   ├── variables.tf  
 │   ├── main.tf         # locals, tags e resource group  
 │   ├── network.tf      # VNet, subnets, NSG, IP público, DNS privado  
 │   ├── dns.tf          # registros A (alias) e CAA  
 │   ├── compute.tf      # NIC e VM  
 │   ├── database.tf     # MySQL Flexible Server  
 │   ├── monitoring.tf   # Log Analytics, coleta e alertas  
 │   ├── backup.tf       # Recovery Services Vault  
 │   └── outputs.tf  
 └── scripts/cloud-init.yaml           # Apache, PHP e GLPI no primeiro boot  
   
**Como implantar**  
Pré-requisitos: Azure CLI, Terraform 1.17+, uma zona DNS no Azure e uma chave SSH.  
az login  
 ./bootstrap/backend.sh                       # uma vez: cria o state remoto  
   
 cd infra  
 cp terraform.tfvars.example terraform.tfvars # preencha chave SSH, IP de administração e e-mail  
 export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)  
 terraform init  
 terraform plan -out tfplan  
 terraform apply tfplan  
   
Depois da primeira implantação, toda mudança passa por pull request e pelo pipeline.  
**Custo estimado**  
Cerca de **US$ 70 por mês** em East US, sem descontos: VM B2s, MySQL B1ms com 20 GB, IP público, backup e Log Analytics com teto diário de 1 GB.  
**Lições aprendidas**  
- **OIDC do GitHub com IDs imutáveis.** O *subject* do token passou a incluir os IDs do dono e do repositório (repo:usuario@ID/repo@ID:...). As credenciais federadas no Entra ID precisam seguir esse formato.  
- **Contadores de performance no Linux.** A regra de coleta do Azure Monitor usa Processor(*)\% Processor Time, sem a barra inicial do formato Windows. O diagnóstico veio do Heartbeat e dos logs do agente.  
- **MySQL Burstable não aceita janela de manutenção customizada.** O maintenance_window foi removido, e o recurso marcado como *tainted* foi recuperado com terraform untaint, sem recriar o servidor.  
- **Restore ensaiado antes do corte.** Permissões de arquivo e a senha no config_db.php foram os pontos de falha; os logs do GLPI em /var/log/glpi mostraram a causa em cada caso.  
**Roadmap**  
- Upgrade para GLPI 11 em branch própria  
- NSG dedicado para a subnet do banco  
- Azure Bastion ou acesso SSH via Entra ID, sem porta 22 exposta  
- Application Gateway com WAF na frente da VM  
- Senhas no Azure Key Vault  
- Teste de disponibilidade da URL com alerta  
**Autor**  
**Márcio Souza**, infraestrutura e cloud.[https://www.linkedin.com/in/marcioss/ ](LINKEDIN "LINKEDIN")  
