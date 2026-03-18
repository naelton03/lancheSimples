# Documentação Master — LancheSimples

## 1. Visão geral e objetivo

O **LancheSimples** é um sistema de PDV móvel voltado para lanchonetes que precisam de **agilidade radical no atendimento**. O produto foi concebido em modelo **multi-tenant**, permitindo que várias empresas utilizem o mesmo aplicativo com **isolamento completo de dados por estabelecimento**.

Além do isolamento por empresa, o sistema mantém **rastreabilidade por funcionário** em cada ação relevante da operação, especialmente no lançamento de itens em comandas.

### Objetivos principais

- Reduzir o tempo de treinamento dos operadores.
- Minimizar erros de lançamento durante o atendimento.
- Garantir segregação total dos dados entre lanchonetes.
- Identificar quem realizou cada operação importante.
- Viabilizar uso em múltiplos dispositivos por estabelecimento.

---

## 2. Arquitetura de acesso e hierarquia

O sistema é estruturado em três níveis de acesso.

### Nível 0 — Master Admin

Acesso administrativo global do sistema, disponível exclusivamente por um **campo oculto** na tela inicial.

- **Código de acesso:** `13356436481`
- Responsável por criar novas instâncias de lanchonetes.
- No cadastro inicial da lanchonete, informa-se apenas o **nome do estabelecimento**.
- Após a criação, o sistema gera um **Código de Estabelecimento Único**.

#### Responsabilidades do Master Admin

- Criar estabelecimentos.
- Gerar e vincular identificadores únicos por lanchonete.
- Garantir o provisionamento inicial da nova instância.
- Servir como camada superior de administração do ecossistema multi-tenant.

### Nível 1 — Estabelecimento

Cada lanchonete opera como uma **instância isolada** dentro da plataforma.

- Todo registro pertence obrigatoriamente a um estabelecimento.
- Nenhum dado pode ser compartilhado entre unidades diferentes.
- O isolamento deve ser respeitado na interface, na API, nas consultas e no banco de dados.

### Nível 2 — Funcionário ou dispositivo

No primeiro acesso de um dispositivo, o aplicativo deve executar um onboarding obrigatório com os seguintes dados:

- **Código do Estabelecimento** para vincular o aparelho à lanchonete.
- **Nome do Funcionário** para identificar o operador do dispositivo.
- **CPF** opcional para complementar identificação.

#### Regras de onboarding

- O nome do funcionário deve ficar salvo no armazenamento local do dispositivo.
- O nome salvo será utilizado para **carimbar automaticamente novos pedidos e lançamentos**.
- O dispositivo sempre deve operar no contexto do estabelecimento informado no onboarding.

---

## 3. Funcionalidades do sistema e regras de negócio

### 3.1 Gestão de catálogo

O sistema deve oferecer cadastro rápido e simples de produtos.

#### Itens individuais

Cada item individual deve permitir, no mínimo:

- Nome
- Preço
- Categoria
- Vínculo com o estabelecimento

#### Combos

O sistema deve permitir criação de combos a partir de itens já existentes.

- Um combo agrupa itens previamente cadastrados.
- O combo possui **valor promocional fechado**.
- O combo também pertence a um único estabelecimento.

### 3.2 Operação de comandas

A abertura de comanda deve ser simples e rápida.

#### Identificador da comanda

Uma comanda pode ser identificada por:

- Número da mesa
- Nome do cliente
- Outro identificador curto e operacional

#### Lançamento de itens

A interação deve ser otimizada para uso em atendimento:

- **Um toque** adiciona o item rapidamente.
- **Clique longo** permite inserir observações.

### 3.3 Rastreabilidade e auditoria

Cada lançamento precisa registrar quem executou a ação.

#### Dados mínimos por lançamento

- ID do item
- Quantidade
- Nome do operador
- Horário exato do lançamento

#### Exibição operacional

Na visualização da comanda:

- O nome do operador deve aparecer abaixo de cada item.
- Essa exibição deve ser **discreta**, suficiente para controle do administrador sem poluir a interface.

---

## 4. Design e frontend

A interface deve seguir uma referência visual inspirada no iFood, priorizando fluidez e clareza.

### Diretrizes visuais

- **Fundo:** branco puro.
- **Títulos:** cinza escuro.
- **Descrições:** cinza médio.
- **Cor primária:** vermelho vibrante ou laranja para ações principais.
- **Formato visual:** cantos arredondados em cards e botões.

### Componentes de interface

#### Barra de categorias

- Posicionada no topo da tela.
- Rolagem horizontal.
- Visual em estilo pílula.
- Usada para filtragem instantânea do cardápio.

#### Cards de itens

Cada card deve apresentar:

- Nome em negrito à esquerda.
- Preço em destaque.
- Botão colorido de adicionar à direita.

#### Etiqueta do operador

- Aparece abaixo do nome do item na comanda.
- Exibe o funcionário responsável pelo lançamento.
- Deve ser pequena e discreta.

#### Rodapé fixo

- Exibe o valor total acumulado da comanda.
- Permite abrir o resumo da comanda.

---

## 5. Estrutura técnica e dados

A modelagem de dados deve reforçar o isolamento multi-tenant.

### Regras estruturais

- Todo item, categoria, combo e comanda deve possuir vínculo obrigatório com o **ID da lanchonete**.
- Todo consumo de dados pelo app deve ser filtrado pelo estabelecimento ativo no dispositivo.
- Logs de pedidos devem preservar trilha de auditoria por operador.

### Entidades mínimas sugeridas

#### Estabelecimento

- `id`
- `nome`
- `codigo_estabelecimento`
- `created_at`

#### Funcionário/Operador local

- `nome`
- `cpf` (opcional)
- `estabelecimento_id`
- `device_id` ou identificador local

#### Categoria

- `id`
- `nome`
- `estabelecimento_id`

#### Item

- `id`
- `nome`
- `preco`
- `categoria_id`
- `estabelecimento_id`

#### Combo

- `id`
- `nome`
- `preco_combo`
- `estabelecimento_id`

#### Comanda

- `id`
- `identificador`
- `status`
- `estabelecimento_id`
- `created_at`

#### Lançamento de item

- `id`
- `comanda_id`
- `item_id`
- `quantidade`
- `observacao`
- `nome_operador`
- `lancado_em`
- `estabelecimento_id`

---

## 6. Fluxos principais do produto

### 6.1 Criação de estabelecimento

1. Master Admin acessa o campo oculto.
2. Informa o código administrativo.
3. Cadastra o nome da lanchonete.
4. O sistema gera o código único do estabelecimento.
5. A nova instância fica pronta para vinculação de dispositivos.

### 6.2 Primeiro acesso no dispositivo

1. Operador abre o app pela primeira vez.
2. Informa o código do estabelecimento.
3. Informa seu nome.
4. Informa CPF, se desejar.
5. O app salva os dados localmente.
6. O dispositivo passa a operar vinculado àquela lanchonete.

### 6.3 Operação de venda

1. Operador abre ou seleciona uma comanda.
2. Filtra a categoria desejada.
3. Adiciona itens com um toque.
4. Usa clique longo quando precisar incluir observação.
5. Cada lançamento grava operador, horário e contexto do estabelecimento.
6. A comanda mostra os itens e suas respectivas etiquetas de operador.

---

## 7. Requisitos não funcionais

### Segurança

- O acesso Master Admin deve permanecer oculto para operação comum.
- O código administrativo deve ser tratado com cuidado e idealmente evoluir para mecanismo mais seguro em produção.
- Toda consulta multi-tenant deve validar o contexto do estabelecimento.

### Usabilidade

- Fluxos críticos devem exigir o mínimo de toques possível.
- Interface deve priorizar leitura rápida e operação sob pressão.
- Componentes visuais devem manter consistência para reduzir curva de aprendizagem.

### Sincronização

- Múltiplos aparelhos do mesmo estabelecimento devem compartilhar dados em tempo real.
- O sistema precisa impedir vazamento de eventos entre estabelecimentos distintos.

### Auditoria

- Toda ação operacional relevante deve permitir rastreio posterior.
- A trilha de auditoria deve apoiar conferência administrativa sem comprometer a experiência do operador.

---

## 8. Cronograma de desenvolvimento

### Fase 1 — Fundação

- Implementar módulo Master Admin.
- Criar backdoor de segurança para o painel oculto.
- Desenvolver lógica de geração de tokens/códigos para lanchonetes.

### Fase 2 — Onboarding

- Criar tela de configuração inicial para novos dispositivos.
- Salvar dados do funcionário localmente.
- Validar vínculo do dispositivo com o estabelecimento.

### Fase 3 — Catálogo

- Construir telas de cadastro de categorias.
- Implementar cadastro de itens.
- Implementar cadastro e composição de combos.

### Fase 4 — Operação

- Construir interface de vendas inspirada no iFood.
- Implementar comandas.
- Adicionar sincronização em tempo real entre aparelhos da mesma lanchonete.

### Fase 5 — Refinamento

- Ajustar interface.
- Testar rastreabilidade dos pedidos.
- Preparar publicação/instalação para Android e iOS.

---

## 9. Backlog inicial sugerido

### Produto e arquitetura

- [ ] Definir stack oficial do app e backend.
- [ ] Definir estratégia de autenticação do Master Admin.
- [ ] Definir geração e formato do código de estabelecimento.
- [ ] Definir mecanismo de sincronização em tempo real.

### Dados e domínio

- [ ] Modelar entidades multi-tenant.
- [ ] Implementar constraints de isolamento por estabelecimento.
- [ ] Estruturar log de auditoria por operador.

### Aplicativo

- [ ] Criar onboarding de dispositivo.
- [ ] Criar cadastro de categorias, itens e combos.
- [ ] Criar tela principal operacional de comandas.
- [ ] Criar rodapé fixo com total e resumo.

### Operação e qualidade

- [ ] Definir testes para rastreabilidade.
- [ ] Validar sincronização concorrente entre dispositivos.
- [ ] Preparar build e distribuição mobile.

---

## 10. Resumo executivo

O LancheSimples deve ser um PDV móvel de operação extremamente simples, mas com arquitetura robusta de isolamento multi-tenant e auditoria por operador. O diferencial está na combinação entre:

- rapidez de uso,
- visual familiar inspirado em aplicativos de delivery,
- rastreabilidade por funcionário,
- e capacidade de múltiplos dispositivos por estabelecimento.

Esta documentação serve como base inicial para decisões de produto, modelagem de dados, UX e planejamento técnico.
