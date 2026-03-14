# Caderno de Testes — Granix

> **Como usar:** Para cada caso de teste, marque ✅ (passou), ❌ (falhou) ou ⚠️ (parcial/observação).
> Versão testada: ___________   Data: ___________   Dispositivo: ___________

---

## 1. Boot e Autenticação

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 1.1 | Primeiro acesso (sem dados) | Desinstalar/limpar app e abrir | Splash → OnboardingScreen (slides) | | |
| 1.2 | Acesso com dados já cadastrados | Abrir app com dados existentes | Splash → HomeScreen | | |
| 1.3 | Biometria ativada | Ativar biometria nas config., fechar app, reabrir | LockScreen solicita biometria antes de abrir | | |
| 1.4 | Biometria desativada | Desativar biometria, fechar app, reabrir | Abre direto sem pedir biometria | | |
| 1.5 | Widget nativo → novo gasto | Tocar no widget "Novo Gasto" na home do SO | Abre formulário de gasto diretamente | | |
| 1.6 | Widget nativo → nova receita | Tocar no widget "Nova Receita" na home do SO | Abre formulário de receita diretamente | | |

---

## 2. Setup Wizard (Cadastro Inicial)

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 2.1 | Navegação entre passos (avançar) | Preencher campos e tocar "Próximo" em cada passo | Avança do passo 1 ao 6 sem erros | | |
| 2.2 | Botão voltar nos slides (passo 1–5) | Em qualquer passo 1–5, tocar na seta de voltar | Retorna ao passo anterior | | |
| 2.3 | Pular etapa de gastos fixos | Tocar "Pular esta etapa" no passo 4 | Avança para o passo 5 sem adicionar gastos | | |
| 2.4 | Pular etapa de receitas fixas | Tocar "Pular esta etapa" no passo 5 | Avança para o passo 6 | | |
| 2.5 | Adicionar gasto fixo com dia do mês | Passo 4: preencher desc + valor + categoria, ajustar dia p/ ex. dia 10, tocar "Adicionar" | Item aparece na lista com "dia 10" | | |
| 2.6 | Adicionar receita fixa com dia do mês | Passo 5: mesmo procedimento | Item aparece na lista com o dia configurado | | |
| 2.7 | Remover item da lista (gastos/receitas) | Tocar no X de um item adicionado | Item é removido da lista | | |
| 2.8 | Dialog de replicação ao concluir | Adicionar ≥1 gasto ou receita fixo e tocar "Concluir" | Aparece dialog "Replicar lançamentos fixos" com stepper de meses | | |
| 2.9 | Replicar para 3 meses | No dialog de replicação, ajustar para 3 meses e confirmar | Cria 3 lançamentos por gasto/receita fixo, cada um no dia configurado | | |
| 2.10 | Só este mês ao concluir | No dialog de replicação, tocar "Só este mês" | Cria apenas 1 lançamento por item, no dia configurado | | |
| 2.11 | Cadastro de forma de pagamento | Passo 2: adicionar forma (ex: Nubank Débito) | Forma aparece na lista; disponível nos formulários | | |
| 2.12 | Cadastro de pessoas | Passo 3: adicionar pessoa (ex: Cônjuge) | Pessoa aparece nas opções de "Pessoa" nos gastos | | |
| 2.13 | Cadastro de orçamentos | Passo 3 ou 6: definir limite por categoria | Orçamentos aparecem nas barras de progresso na Home | | |
| 2.14 | Concluir setup → HomeScreen | Tocar "Concluir" sem gastos/receitas fixos | Vai direto para HomeScreen sem dialog de meses | | |

---

## 3. Home Screen (Dashboard)

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 3.1 | Gráfico mensal | Abrir HomeScreen com lançamentos no mês | Gráfico de barras/pizza exibe dados corretamente | | |
| 3.2 | Navegação de mês (← →) | Tocar nas setas de navegação de mês | Dados atualizam para o mês selecionado | | |
| 3.3 | Dica de categoria | Ter gastos em categoria dominante | Card de dica aparece acima das barras de orçamento | | |
| 3.4 | Alertas financeiros (destaques) | Ter dados que disparem alertas (ex: saldo negativo) | Cards de alerta aparecem sem fundo colorido, só borda | | |
| 3.5 | Barras de orçamento por categoria | Ter orçamentos e gastos cadastrados | Barras mostram % gasto vs limite; cores variam por nível | | |
| 3.6 | FAB → novo gasto | Tocar no botão + flutuante | Abre formulário de novo gasto | | |
| 3.7 | FAB → nova receita | Tocar no botão + e escolher receita | Abre formulário de nova receita | | |
| 3.8 | Totais corretos | Lançar R$100 gasto e R$200 receita no mês atual | Saldo exibido: R$100; gasto: R$100; receita: R$200 | | |
| 3.9 | Sem dados no mês | Navegar para mês sem nenhum lançamento | Exibe mensagem/estado vazio sem erros | | |
| 3.10 | Scroll sem overflow | Rolar a tela em dispositivo pequeno | Sem mensagem "RenderFlex overflowed" | | |

---

## 4. Formulário de Gasto

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 4.1 | Salvar gasto simples | Preencher valor, categoria, data e descrição → Salvar | Gasto aparece na lista do mês | | |
| 4.2 | Campo data sempre visível | Abrir formulário de gasto (fixo ou variável, recorrente ou não) | Date picker sempre presente no formulário | | |
| 4.3 | Seletor de data | Tocar no campo Data | Abre DatePicker; data selecionada reflete no campo | | |
| 4.4 | Forma de pagamento | Abrir formulário após cadastrar formas | Dropdown exibe as formas cadastradas | | |
| 4.5 | Pessoa | Abrir formulário após cadastrar pessoas | Dropdown exibe as pessoas cadastradas | | |
| 4.6 | Tipo Fixo + Recorrente → dialog de replicação | Selecionar tipo "Fixo", ativar "Recorrente", salvar | Aparece dialog com stepper de meses E stepper de dia do mês | | |
| 4.7 | Dialog replicação — dia do mês padrão | Abrir dialog de replicação com data 15/03 | Stepper de dia inicia em 15 | | |
| 4.8 | Replicar 3 meses no dia 10 | No dialog, ajustar para 3 meses / dia 10 → Replicar | 3 gastos criados: dia 10 do mês atual, mês+1 e mês+2 | | |
| 4.9 | Só este mês (dialog) | No dialog de replicação, tocar "Só este mês" | Apenas 1 gasto criado com a data do formulário (sem usar o dia do dialog) | | |
| 4.10 | Tipo Variável não abre dialog | Selecionar tipo "Variável", salvar | Salva diretamente sem exibir dialog de replicação | | |
| 4.11 | Fixo sem recorrente não abre dialog | Selecionar tipo "Fixo", desativar "Recorrente", salvar | Salva diretamente sem exibir dialog de replicação | | |
| 4.12 | Gasto parcelado | Ativar "Parcelado", definir 3 parcelas, salvar | Cria 3 gastos com valor/nParcela corretos | | |
| 4.13 | Validação: botão Salvar desabilitado sem descrição | Deixar descrição vazia | Botão "Salvar Gasto" fica cinza/desabilitado | | |
| 4.14 | Editar gasto existente | Abrir gasto da lista, alterar valor, salvar | Valor atualizado na lista; não abre dialog de replicação | | |

---

## 5. Formulário de Receita

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 5.1 | Salvar receita simples | Preencher valor, categoria, data e descrição → Salvar | Receita aparece na lista do mês | | |
| 5.2 | Campo data sempre visível | Abrir formulário (fixo ou variável, recorrente ou não) | Date picker sempre presente | | |
| 5.3 | Tipo Fixo + Recorrente → dialog | Selecionar "Fixo" + ativar "Recorrente", salvar | Dialog com stepper de meses e dia do mês | | |
| 5.4 | Replicar receita para 6 meses no dia 5 | No dialog, ajustar 6 meses / dia 5 → Replicar | 6 receitas criadas, cada uma no dia 5 do respectivo mês | | |
| 5.5 | Só este mês | Tocar "Só este mês" no dialog | 1 receita com data do formulário | | |
| 5.6 | Tipo Variável sem dialog | Selecionar "Variável", salvar | Salva direto | | |
| 5.7 | Editar receita não abre dialog | Editar receita existente (fixo+recorrente) e salvar | Salva sem dialog | | |

---

## 6. Tela de Meus Gastos

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 6.1 | Listagem de gastos | Abrir tela com gastos cadastrados | Gastos do mês exibidos com descrição, categoria, data e valor | | |
| 6.2 | Exibição de forma de pagamento | Gasto com forma de pagamento definida | Forma de pagamento visível no card/subtítulo do item | | |
| 6.3 | Exibição de pessoa | Gasto com pessoa definida | Nome da pessoa visível no card/subtítulo do item | | |
| 6.4 | Busca por descrição | Digitar parte da descrição no campo de busca | Lista filtra mostrando apenas os correspondentes | | |
| 6.5 | Filtro por categoria | Filtrar por "Alimentação" | Exibe apenas gastos da categoria Alimentação | | |
| 6.6 | Navegação de mês | Tocar nas setas de mês | Lista atualiza para o mês selecionado | | |
| 6.7 | Adicionar gasto via FAB | Tocar no botão + | Abre formulário de novo gasto | | |
| 6.8 | Editar gasto na lista | Tocar em um gasto ou na opção de editar | Abre formulário preenchido com dados do gasto | | |
| 6.9 | Excluir gasto | Deslizar item ou tocar em excluir | Gasto removido da lista; totais atualizados | | |
| 6.10 | Edição em massa | Selecionar múltiplos gastos e aplicar ação em massa | Ação aplicada a todos os selecionados | | |
| 6.11 | Lista vazia | Abrir tela sem gastos no mês | Exibe estado vazio sem erros | | |

---

## 7. Tela de Insights

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 7.1 | Abrir sem overflow | Abrir InsightsScreen em dispositivo pequeno (ex: 5") | Sem "RenderFlex overflowed" | | |
| 7.2 | Scroll completo | Rolar toda a tela de insights até o final | Sem erro de overflow; padding inferior adequado | | |
| 7.3 | Cards com fundo branco | Verificar visual de todos os cards | Todos têm fundo branco e borda colorida | | |
| 7.4 | Sem seção "Regras Financeiras" | Verificar layout da tela | Não existe mais a seção "Regras Financeiras" separada | | |
| 7.5 | Alertas integrados | Ter dados que disparem regras (sem receita, saldo negativo, etc.) | Alertas aparecem na seção "Alertas Financeiros" | | |
| 7.6 | Filtro de período | Trocar período (mês atual, 3 meses, ano) | Dados dos cards atualizam corretamente | | |
| 7.7 | Card "Compras no Cartão" | Ter gastos com forma de pagamento tipo Crédito | Card exibe total e percentual correto | | |
| 7.8 | Card "Meta de Economia" | Ter receita e gastos definidos | Card exibe % economizado; borda colorida | | |
| 7.9 | Gasto diário sem "R$ R$" duplicado | Verificar o card de gasto diário vs renda diária | Exibe "Gasto médio diário: R$ X,XX • Renda diária: R$ Y,YY" (sem duplicar "R$") | | |
| 7.10 | Cards de destaque (destaques do período) | Ter dados suficientes no período | Cards de destaque exibem borda colorida e fundo branco | | |

---

## 8. Configurações do Sistema

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 8.1 | Alternar tema claro/escuro | Tocar na opção de tema | Tema muda imediatamente em toda a app | | |
| 8.2 | Ativar/desativar biometria | Tocar na opção de biometria | Toggle muda; próximo boot exige/ignora biometria conforme config | | |
| 8.3 | Gerar massa de dados | Tocar em "Gerar massa de dados" | Dados são criados; formas de pagamento, pessoas e orçamentos são criados se estiverem vazios | | |
| 8.4 | Excluir todos os dados — dialog informativo | Tocar em "Excluir todos os dados" e confirmar | Aparece dialog "Dados removidos" com botão "Ir para cadastro inicial" | | |
| 8.5 | Excluir dados → navega para SetupWizard | Tocar "Ir para cadastro inicial" no dialog | Navega para SetupWizardScreen; flag onboarding_completo removida | | |
| 8.6 | Setup após exclusão começa do passo 0 | Após excluir dados e ir para setup | Setup começa do início (boas-vindas/passo 0) | | |
| 8.7 | Exportar backup | Tocar em "Backup" → exportar | Gera arquivo JSON com todos os dados | | |
| 8.8 | Importar backup | Exportar, excluir dados, importar o JSON | Dados restaurados corretamente | | |

---

## 9. Configurações (Formas, Pessoas, Orçamentos)

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 9.1 | Adicionar forma de pagamento | Ir em Configurações → Formas de Pagamento → adicionar | Forma aparece na lista e nos dropdowns dos formulários | | |
| 9.2 | Excluir forma de pagamento | Excluir uma forma existente | Remove da lista e dos dropdowns | | |
| 9.3 | Adicionar pessoa | Ir em Configurações → Pessoas → adicionar | Pessoa aparece nos dropdowns dos formulários | | |
| 9.4 | Excluir pessoa | Excluir uma pessoa existente | Remove da lista | | |
| 9.5 | Definir orçamento por categoria | Ir em Configurações → Orçamentos → editar limite | Barra de progresso na Home reflete o novo limite | | |
| 9.6 | Zerar orçamento | Definir limite 0 para uma categoria | Barra não aparece ou aparece como sem limite | | |

---

## 10. Relatórios

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 10.1 | Abrir relatórios | Navegar para RelatoriosScreen | Tela abre sem erros | | |
| 10.2 | Gráficos com dados | Ter gastos no período selecionado | Gráficos exibem dados corretamente | | |
| 10.3 | Exportar PDF | Tocar em exportar PDF | Gera e compartilha arquivo PDF | | |
| 10.4 | Filtrar por período | Alterar período do relatório | Gráficos e totais atualizam | | |

---

## 11. Todos os Registros

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 11.1 | Listagem mista | Abrir TodosRegistrosScreen com gastos e receitas | Exibe ambos os tipos na mesma lista | | |
| 11.2 | Busca global | Digitar termo na busca | Filtra tanto gastos quanto receitas | | |
| 11.3 | Exportar CSV | Tocar em exportar CSV | Gera arquivo CSV com todos os registros | | |

---

## 12. Lançamentos Recorrentes por Data

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 12.1 | Visualizar por período | Abrir RegistrosPorDatasScreen | Exibe lançamentos recorrentes agrupados | | |
| 12.2 | Selecionar intervalo | Definir data de início e fim | Filtra lançamentos no período | | |

---

## 13. Múltiplos Gastos / Receitas em Lote

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 13.1 | Lançar múltiplos gastos | Abrir MultiplosGastosScreen, adicionar 3 itens e salvar | 3 gastos criados | | |
| 13.2 | Lançar múltiplas receitas | Mesmo para receitas | 3 receitas criadas | | |

---

## 14. Assinatura / Premium

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 14.1 | Trial ativo | App em período de trial | Acesso completo; nenhum bloqueio | | |
| 14.2 | Trial expirado sem assinatura | Simular trial expirado | Redireciona para PaywallScreen | | |
| 14.3 | Tela de Paywall | Abrir PaywallScreen | Exibe opções de assinatura sem erros | | |

---

## 15. Regressão — Mudanças Recentes

> Testes focados nas funcionalidades alteradas nas últimas sessões.

| # | Caso de Teste | Passos | Resultado Esperado | Status | Obs |
|---|---------------|--------|--------------------|--------|-----|
| 15.1 | Cards sem fundo cinza (alertas Home) | Abrir Home com alertas | Alertas sem fundo colorido (fundo branco + borda) | | |
| 15.2 | Cards sem fundo cinza (Insights) | Abrir InsightsScreen | Todos os cards com fundo branco | | |
| 15.3 | Todos os cards com borda colorida | Verificar cards em Home e Insights | Todos têm BorderSide colorida | | |
| 15.4 | Dica de categoria acima das barras | Verificar posição na Home | Dica aparece ANTES da primeira barra de categoria | | |
| 15.5 | Formulário gasto: data sempre visível | Ativar/desativar recorrente no formulário | Campo data não muda de formato — sempre date picker | | |
| 15.6 | Formulário receita: data sempre visível | Mesmo para receita | Campo data não muda de formato | | |
| 15.7 | Dialog replicação só para Fixo+Recorrente | Salvar gasto Variável+Recorrente | **Não** abre dialog de replicação | | |
| 15.8 | Dialog replicação contém dia do mês | Salvar gasto Fixo+Recorrente | Dialog tem stepper de meses E stepper de dia do mês | | |
| 15.9 | Botão voltar no Setup Wizard | Ir ao passo 3, tocar em voltar | Retorna ao passo 2 | | |
| 15.10 | Excluir dados → SetupWizard (não Onboarding) | Excluir todos os dados → Ir para cadastro inicial | Abre SetupWizardScreen (não OnboardingScreen) | | |
| 15.11 | Massa de dados cria formas+pessoas+orçamentos | Com base vazia, gerar massa de dados | Cria formas de pagamento, pessoas e orçamentos automaticamente | | |
| 15.12 | Setup Wizard: dia do mês na lista | Adicionar gasto fixo com dia 15 no wizard | Lista mostra "... • dia 15" | | |
| 15.13 | Setup Wizard: dialog de replicação no concluir | Ter gastos/receitas fixos no wizard e concluir | Dialog "Replicar lançamentos fixos" aparece antes de salvar | | |

---

## Registro de Bugs Encontrados

| # | Tela | Descrição do Bug | Severidade | Status |
|---|------|-----------------|------------|--------|
| | | | | |
| | | | | |
| | | | | |

> **Severidade:** 🔴 Crítico (bloqueia uso) · 🟠 Alto (funcionalidade quebrada) · 🟡 Médio (comportamento incorreto) · 🟢 Baixo (cosmético)
