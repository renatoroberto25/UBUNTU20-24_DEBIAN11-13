# Hardening Shellscript DEB-like

Conjunto de scripts para auditoria e remediacao tecnica em sistemas Debian-like, com foco em Ubuntu 20.04/22.04/24.04 e Debian 11/12/13.

O projeto executa verificacoes objetivas de hardening, registra resultados em log/CSV, aplica remediacoes automatizaveis quando tecnicamente seguro e separa como `SEM_AUTO` os itens que exigem decisao de arquitetura, politica do cliente ou revisao manual.

## Escopo

Este pacote cobre controles de:

- Kernel e modulos
- Filesystem, montagem e permissoes
- Boot e bootloader
- Servicos do sistema
- Rede e sysctl
- TLS
- SSH
- Senhas, contas e PAM
- Sudo
- Auditoria e logs
- Integridade
- Contas de sistema
- Home directories

## Como Executar

Execute a partir do diretorio do projeto:

```bash
cd HARDENING_SHELLSCRIPT_UBT20-24_DEB11-13
```

Auditoria:

```bash
bash executor.sh audit
```

Remediacao dos itens reprovados no ultimo audit:

```bash
sudo bash executor.sh remed
```

Relatorio simples dos itens ainda reprovados:

```bash
bash executor.sh report
```

Rollback da ultima remediacao:

```bash
sudo bash executor.sh rollback
```

Tambem e possivel abrir o menu interativo:

```bash
bash executor.sh
```

## Componentes

### `executor.sh`

Orquestra a execucao do projeto.

Principais funcoes:

- roda os scripts de auditoria em `AUDIT_SH`;
- gera CSV com os itens aprovados e reprovados;
- identifica os IDs reprovados;
- chama os scripts de remediacao por grupo em `REMED_GROUPS`;
- executa audit pos-remediacao;
- gera lista de itens corrigidos;
- registra manifesto de rollback.

### `AUDIT_SH/audit.sh`

Contem os checks de auditoria.

Cada item deve ser objetivo: retorna `PASS` quando a condicao medida esta conforme e `FAIL` quando nao esta. O audit nao tenta inferir politica externa nem substituir decisao de arquitetura. Quando um item tem escopo limitado, a descricao do item deve refletir exatamente o que esta sendo medido.

### `REMED_GROUPS/`

Contem os scripts de remediacao por grupo operacional.

Os grupos atuais incluem:

- `kernel.sh`
- `filesystem.sh`
- `boot.sh`
- `system.sh`
- `network.sh`
- `tls.sh`
- `ssh.sh`
- `accounts.sh`
- `sudo.sh`
- `audit_logs.sh`
- `integrity.sh`
- `permissions.sh`
- `system_accounts.sh`
- `home.sh`

Cada remediacao retorna um status:

- `OK`: item remediado automaticamente;
- `SEM_AUTO`: item exige decisao manual, pacote, compatibilidade ou politica;
- `FAIL`: tentativa de remediacao falhou.

## Logs Gerados

Os arquivos ficam em `logs/`.

Auditoria:

- `logs/audit/audit-current.csv`
- `logs/audit/audit-<host>-<data>.log`
- `logs/audit/audit-post-current.csv`
- `logs/audit/audit-post-<host>-<data>.log`

Remediacao:

- `logs/remed/failed-<host>-<data>.ids`
- `logs/remed/remed-<host>-<data>.log`
- `logs/remed/fixed-<host>-<data>.csv`

Rollback:

- `logs/remed/rollback/rollback-<data>-<host>.manifest`
- backups individuais dos arquivos alterados

Observacao: o arquivo `failed-*.ids` representa os itens reprovados antes da remediacao e serve como entrada para o executor. O resultado final deve ser avaliado pelo `audit-post-current.csv` e pelo log `audit-post-*.log`.

## Interpretacao da Aderencia

A meta operacional deste pacote e atingir aderencia minima de 70% em execucao automatizada conservadora.

Uma faixa remanescente em torno de 30% e esperada e nao deve ser interpretada automaticamente como falha do script. Essa parcela normalmente representa itens que nao devem ser alterados sem decisao tecnica do cliente, validacao de compatibilidade ou desenho de arquitetura.

Exemplos de itens tipicamente decisorios:

- `auditd/AIDE`: depende de instalar pacote, inicializar base, carregar regra e definir politica de boot;
- `filesystem/fstab/particao`: depende da arquitetura da maquina e do desenho de montagem;
- `PAM`: depende de stack aprovada e padrao corporativo de autenticacao;
- `TLS/SSH AllowUsers/time sync`: depende de compatibilidade, usuarios permitidos e politica do cliente;
- arquivos orfaos e SUID/SGID: exigem revisao humana para evitar quebra operacional;
- servicos e pacotes especificos: dependem do papel do host.

Portanto, a leitura recomendada e:

- `PASS/APROVADO`: controle conforme ao escopo auditado;
- `FAIL/REPROVADO`: controle nao conforme ou dependente de acao manual;
- `OK`: remediacao automatica aplicada;
- `SEM_AUTO`: item reconhecido, mas corretamente preservado para decisao manual;
- `FAIL` em remediacao: erro real de execucao ou tentativa nao concluida.

## Politica de Automacao

O projeto evita remediar automaticamente itens que possam quebrar servico, alterar arquitetura ou impor politica nao aprovada.

Sao bons candidatos a automacao:

- sysctl simples e reversivel;
- permissoes de arquivos sensiveis;
- hardening basico de SSH;
- parametros objetivos de sudo;
- configuracoes locais com backup e rollback;
- regras de auditoria apenas quando `auditd/augenrules/auditctl` estao disponiveis e a regra fica ativa.

Devem permanecer manuais ou condicionais:

- instalacao de pacotes;
- alteracao de PAM;
- alteracao de bootloader;
- remocao de servicos;
- mudancas em particionamento/fstab;
- politica de TLS;
- definicao de usuarios/grupos autorizados;
- tratamento de arquivos sem owner/grupo ou binarios SUID/SGID.

## Rollback

Antes de alterar arquivos, os scripts registram backup ou metadados no manifesto de rollback.

Para desfazer a ultima remediacao:

```bash
sudo bash executor.sh rollback
```

Para usar um manifesto especifico:

```bash
sudo bash executor.sh rollback logs/remed/rollback/rollback-<data>-<host>.manifest
```

## Boas Praticas de Uso

1. Executar `audit` antes de qualquer remediacao.
2. Revisar os itens reprovados.
3. Executar `remed` em janela controlada.
4. Validar o `audit-post-current.csv`.
5. Tratar os itens `SEM_AUTO` como pendencias de decisao, nao como erro do executor.
6. Preservar os logs da execucao para evidencia.
