#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_54.log"
DOC_FILE="${DOCS_DIR}/NEXT_FUNCTIONAL_PHASE_PLAN.md"
VISUAL_DOC_FILE="${DOCS_DIR}/VISUAL_IDENTITY_AND_ATTENDANCE_PLAN.md"
FLOW_DOC_FILE="${DOCS_DIR}/ATTENDANCE_OPERATIONAL_FLOW.md"

echo "== Etapa 54: Planejamento da proxima fase funcional do produto =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups dos documentos de controle..."

for file in \
  "${DOC_FILE}" \
  "${VISUAL_DOC_FILE}" \
  "${FLOW_DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/CONTEXTO_PROJETO.md" \
  "${BASE_DIR}/CHANGELOG.md" \
  "${BASE_DIR}/DECISOES_TECNICAS.md" \
  "${BASE_DIR}/PENDENCIAS.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando arquivos de logos na raiz do projeto..."

LOGO_MAIN="${BASE_DIR}/chatbot_logo.png"
LOGO_COMPANY="${BASE_DIR}/favicon.png"
LOGO_ICON="${BASE_DIR}/lh_chatbot_favicon.png"

if [ ! -f "${LOGO_MAIN}" ]; then
  echo "ERRO: logo principal nao encontrado: chatbot_logo.png"
  exit 1
fi

if [ ! -f "${LOGO_COMPANY}" ]; then
  echo "ERRO: logo da empresa nao encontrado: favicon.png"
  exit 1
fi

if [ ! -f "${LOGO_ICON}" ]; then
  echo "ERRO: favicon do aplicativo nao encontrado: lh_chatbot_favicon.png"
  exit 1
fi

echo "Gerando plano da proxima fase funcional..."

cat > "${DOC_FILE}" <<'DOC'
# Next Functional Phase Plan

## Visao geral

Este documento registra o planejamento da proxima fase funcional do produto.

## Nome da fase

Fase 10 - Experiencia visual e atendimento profissional

## Objetivo

Transformar o sistema em uma central profissional de atendimento via WhatsApp oficial da Meta, com identidade visual propria da LH Solucao Chat Bot, fluxo operacional por departamentos, filas, responsaveis, encerramento com avaliacao e layout adaptativo para qualquer tamanho de tela.

## Premissas

Premissas:

- manter todos os textos em PT-BR
- manter layout responsivo para desktop, notebook, tablet e celular
- usar os logos existentes na raiz do projeto
- preservar funcoes ja existentes
- nao quebrar auditoria operacional criada nas etapas 43 ate 53
- implementar em etapas pequenas
- fazer backup antes de cada alteracao
- validar backend, frontend, dominio e documentacao por etapa

## Logos identificados

Arquivos:

- chatbot_logo.png
- favicon.png
- lh_chatbot_favicon.png

Uso planejado:

- chatbot_logo.png como logo principal do login e telas institucionais
- favicon.png como logo compacto da empresa
- lh_chatbot_favicon.png como favicon e icone compacto do aplicativo

## Identidade visual planejada

Cores principais:

- azul institucional
- laranja de destaque
- verde operacional
- branco para superficies
- cinza escuro para textos
- vermelho somente para alerta e erro

Aplicacoes:

- login com fundo profissional
- sidebar com logo compacto
- header responsivo
- botoes primarios em azul ou laranja
- indicadores de sucesso em verde
- cards com sombra leve
- estados vazios com identidade do chatbot
- favicon do navegador com icone do aplicativo

## Funcionalidades da nova fase

Funcionalidades planejadas:

- identidade visual completa com logos e favicon
- layout profissional dinamico e adaptativo
- caixa de entrada operacional
- status de atendimento da conversa
- departamentos de atendimento
- fila por departamento
- atribuicao de responsavel
- nome do usuario que responde
- transferencia entre departamentos
- respostas rapidas por departamento
- notas internas
- tags de contato e conversa
- mensagem de encerramento com avaliacao
- historico do contato
- dashboard de atendimento
- indicadores de SLA e tempo de resposta
- painel mobile otimizado

## Sequencia proposta

Etapas propostas:

- Etapa 55 - Aplicar identidade visual com logos e favicon
- Etapa 56 - Criar layout responsivo profissional da central de atendimento
- Etapa 57 - Criar status operacional das conversas
- Etapa 58 - Criar departamentos e filas de atendimento
- Etapa 59 - Criar atribuicao de responsavel e nome do atendente
- Etapa 60 - Criar respostas rapidas por departamento
- Etapa 61 - Criar notas internas e tags
- Etapa 62 - Criar encerramento com avaliacao do atendimento
- Etapa 63 - Criar dashboard de atendimento
- Etapa 64 - Revisao final da fase de atendimento profissional

## Primeira implementacao recomendada

A primeira etapa de codigo recomendada e:

Etapa 55 - Aplicar identidade visual com logos e favicon

Motivo:

- melhora visual imediata
- baixo risco funcional
- prepara base visual para as demais telas
- permite validar responsividade inicial sem alterar banco de dados

## Resultado esperado da fase

Resultado esperado:

- sistema com aparencia profissional
- atendimento organizado por filas
- departamentos configuraveis
- responsaveis visiveis
- conversas com status operacional
- encerramento padronizado com avaliacao
- uso fluido em telas pequenas e grandes
- base pronta para operacao real de atendimento
DOC

echo "Gerando plano visual e de identidade..."

cat > "${VISUAL_DOC_FILE}" <<'DOC'
# Visual Identity And Attendance Plan

## Visao geral

Este documento define o plano visual da nova fase de atendimento profissional.

## Identidade visual

A identidade visual deve ser baseada nos logos existentes na raiz do projeto.

Arquivos:

- chatbot_logo.png
- favicon.png
- lh_chatbot_favicon.png

## Paleta sugerida

Cores:

- azul para identidade institucional e navegacao
- laranja para destaques e chamadas principais
- verde para confirmacao, sucesso e atendimento ativo
- branco para fundos e cards
- cinza para textos e divisorias
- vermelho para erros e alertas criticos

## Aplicacao visual por area

Login:

- logo principal em destaque
- fundo profissional com degradacao suave
- card de login centralizado
- favicon do aplicativo

Sidebar:

- logo compacto
- menu com estados ativo e hover
- agrupamento de modulos

Header:

- nome da tela
- usuario logado
- indicador de status operacional
- botao de menu em telas pequenas

Central de atendimento:

- lista de conversas
- coluna de conversa ativa
- painel lateral do contato
- composicao de mensagem
- botoes de respostas rapidas
- status visual da conversa

Mobile:

- lista de conversas em tela cheia
- conversa ativa em tela cheia
- botao de retorno
- menu inferior ou header compacto
- botoes com area de toque adequada

## Comportamento adaptativo

Regras:

- desktop com tres colunas
- notebook com duas colunas principais
- tablet com alternancia entre lista e conversa
- celular com navegacao por tela
- nenhum conteudo deve gerar rolagem horizontal
- botoes devem ser acessiveis por toque
- textos longos devem quebrar linha corretamente

## Componentes visuais recomendados

Componentes:

- app shell
- sidebar responsiva
- topbar
- conversation list
- conversation header
- message bubble
- internal note card
- quick reply drawer
- department queue tabs
- contact profile panel
- rating card
- SLA badge
- empty state com logo do chatbot
DOC

echo "Gerando fluxo operacional de atendimento..."

cat > "${FLOW_DOC_FILE}" <<'DOC'
# Attendance Operational Flow

## Visao geral

Este documento define o fluxo operacional proposto para atendimento profissional.

## Fluxo de entrada

Fluxo:

- mensagem recebida pela API oficial da Meta
- conversa criada ou atualizada
- conversa entra na fila geral
- sistema tenta definir departamento padrao
- atendente assume ou supervisor distribui
- conversa passa para em atendimento

## Departamentos

Departamentos iniciais sugeridos:

- Comercial
- Suporte
- Financeiro
- Pos-venda
- Tecnico
- Administrativo

## Filas

Filas sugeridas:

- Fila geral
- Sem responsavel
- Comercial
- Suporte
- Financeiro
- Pos-venda
- Aguardando cliente
- Em atraso
- Encerradas

## Status de conversa

Status sugeridos:

- novo
- em atendimento
- aguardando cliente
- aguardando interno
- resolvido
- encerrado
- arquivado

## Responsavel pelo atendimento

Cada conversa deve permitir:

- responsavel atual
- nome do responsavel
- data de atribuicao
- historico de transferencia
- departamento atual

## Nome do usuario na resposta

O sistema deve registrar:

- usuario que enviou a mensagem
- nome do usuario
- data de envio
- departamento do usuario no momento do envio

Uso sugerido na interface:

- mostrar internamente quem respondeu
- permitir assinatura opcional para o cliente

## Mensagem de encerramento com avaliacao

Mensagem padrao sugerida:

Ola. Seu atendimento foi finalizado.

Para nos e muito importante saber como foi sua experiencia.

Por favor, avalie este atendimento respondendo com uma nota de 1 a 5:

1 - Muito ruim
2 - Ruim
3 - Regular
4 - Bom
5 - Excelente

Se desejar, voce tambem pode enviar um comentario com sua sugestao.

Obrigado por falar com a LH Solucao.

## Dados da avaliacao

Campos sugeridos:

- conversationId
- rating
- comment
- closedByUserId
- closedByName
- closedAt
- departmentId
- departmentName

## Respostas rapidas

Categorias sugeridas:

- Saudacao
- Pedido de dados
- Horario de atendimento
- Encaminhamento
- Encerramento
- Agradecimento
- Link de pagamento
- Prazo de retorno

## Notas internas

Uso:

- registrar informacoes internas
- manter historico operacional
- orientar proximo atendente
- nao enviar ao cliente

## Tags

Tags sugeridas:

- lead
- cliente
- urgente
- financeiro
- suporte
- orcamento
- renovacao
- reclamacao
- pos-venda

## SLA

Indicadores sugeridos:

- tempo em fila
- tempo desde ultima resposta
- tempo medio de primeira resposta
- conversas sem responsavel
- conversas em atraso
- SLA por departamento

## Dashboard de atendimento

Indicadores sugeridos:

- conversas abertas
- conversas por departamento
- conversas sem responsavel
- atendimentos encerrados hoje
- tempo medio de resposta
- avaliacao media
- mensagens recebidas hoje
- mensagens enviadas hoje
- falhas de envio
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 54 - Planejamento da proxima fase funcional do produto",
    "- [x] Etapa 54 - Planejamento da proxima fase funcional do produto\n- [ ] Etapa 55 - Aplicar identidade visual com logos e favicon"
)

text = text.replace(
    "Etapa 54 - Planejar proxima fase funcional do produto.",
    "Etapa 55 - Aplicar identidade visual com logos e favicon."
)

text = text.replace(
    "Etapa 53 - Encerramento e revisao final da fase operacional de auditoria.",
    "Etapa 54 - Planejamento da proxima fase funcional do produto."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Planejamento da proxima fase funcional do produto criado." not in text:
    text = text.replace(
        "Encerramento e revisao final da fase operacional de auditoria concluida.",
        "Encerramento e revisao final da fase operacional de auditoria concluida.\n\nPlanejamento da proxima fase funcional do produto criado."
    )

if "- docs/NEXT_FUNCTIONAL_PHASE_PLAN.md" not in text:
    text = text.replace(
        "- docs/AUDIT_PHASE_FINAL_REVIEW.md",
        "- docs/NEXT_FUNCTIONAL_PHASE_PLAN.md\n- docs/VISUAL_IDENTITY_AND_ATTENDANCE_PLAN.md\n- docs/ATTENDANCE_OPERATIONAL_FLOW.md\n- docs/AUDIT_PHASE_FINAL_REVIEW.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 53 concluidas",
    "- Etapa 01 ate Etapa 54 concluidas"
)

text = text.replace(
    "- Etapa 54 - Planejamento da proxima fase funcional do produto",
    "- Etapa 55 - Aplicar identidade visual com logos e favicon"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 54 - Planejamento da proxima fase funcional do produto
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Planejada a Fase 10 de experiencia visual e atendimento profissional, incluindo identidade visual com logos, layout responsivo, departamentos, filas, responsaveis, encerramento com avaliacao, dashboard e fluxo operacional de atendimento.
DOC
  fi
done

echo "Validando documentos criados..."

for file in \
  "${DOC_FILE}" \
  "${VISUAL_DOC_FILE}" \
  "${FLOW_DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ ! -f "${file}" ]; then
    echo "ERRO: arquivo nao criado: ${file}"
    exit 1
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${VISUAL_DOC_FILE}" \
  "${FLOW_DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 54
Acao: Planejamento da proxima fase funcional do produto
Data: $(date '+%Y-%m-%d %H:%M:%S')
Documento principal: docs/NEXT_FUNCTIONAL_PHASE_PLAN.md
Documento visual: docs/VISUAL_IDENTITY_AND_ATTENDANCE_PLAN.md
Documento fluxo: docs/ATTENDANCE_OPERATIONAL_FLOW.md
Logos validados: chatbot_logo.png, favicon.png, lh_chatbot_favicon.png
Status: Concluido
DOC

echo ""
echo "== Etapa 54 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 55 - Aplicar identidade visual com logos e favicon"
