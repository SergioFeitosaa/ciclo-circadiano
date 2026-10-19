#!/usr/bin/env bash
# Smoke test da aplicação em execução (backend + MySQL + frontend via Docker Compose).
#
# Uso (com os containers já no ar):
#   bash scripts/smoke-test.sh
#
# Variáveis opcionais:
#   API_URL       (padrão: http://localhost:8080/api)
#   FRONTEND_URL  (padrão: http://localhost:8081)
#   TENTATIVAS    (padrão: 40)  tentativas de espera pela API
#   INTERVALO     (padrão: 3)   segundos entre as tentativas
#
# Requer: bash e curl. O jq é opcional (habilita o teste de criação de avaliação).
# Sai com código 0 se tudo passar e 1 se alguma verificação falhar.

set -uo pipefail

API_URL="${API_URL:-http://localhost:8080/api}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:8081}"
TENTATIVAS="${TENTATIVAS:-40}"
INTERVALO="${INTERVALO:-3}"

CORPO="$(mktemp)"
trap 'rm -f "$CORPO"' EXIT

falhas=0

# requisicao <metodo> <url> [json] [token] -> imprime o status HTTP (000 se não conectou)
requisicao() {
  local metodo="$1" url="$2" dados="${3:-}" token="${4:-}"
  local args=(-sS -m 15 -o "$CORPO" -w '%{http_code}' -X "$metodo")
  if [ -n "$dados" ]; then
    args+=(-H 'Content-Type: application/json' -d "$dados")
  fi
  if [ -n "$token" ]; then
    args+=(-H "Authorization: Bearer $token")
  fi
  # Em falha de conexão o curl já imprime 000 via -w; o exit code é ignorado de propósito.
  curl "${args[@]}" "$url" 2>/dev/null
  return 0
}

# verificar <descricao> <esperado (regex, ex.: 401|403)> <status obtido>
verificar() {
  local descricao="$1" esperado="$2" obtido="$3"
  if [[ "$obtido" =~ ^($esperado)$ ]]; then
    echo "  [OK]    $descricao (HTTP $obtido)"
  else
    echo "  [FALHA] $descricao: esperado HTTP $esperado, recebido $obtido"
    echo "          resposta: $(head -c 300 "$CORPO")"
    falhas=$((falhas + 1))
  fi
}

extrair_token() {
  sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$CORPO"
}

echo "Smoke test"
echo "  API:      $API_URL"
echo "  Frontend: $FRONTEND_URL"
echo

echo "1) Aguardando a API iniciar..."
pronta=0
for ((i = 1; i <= TENTATIVAS; i++)); do
  status="$(requisicao GET "$API_URL/perguntas")"
  if [ "$status" != "000" ]; then
    pronta=1
    break
  fi
  sleep "$INTERVALO"
done
if [ "$pronta" -ne 1 ]; then
  echo "  [FALHA] A API não respondeu após $((TENTATIVAS * INTERVALO))s."
  exit 1
fi
echo "  [OK]    API respondendo"
echo

echo "2) Frontend"
verificar "Página inicial do frontend" "200" "$(requisicao GET "$FRONTEND_URL/")"
echo

echo "3) Segurança das rotas"
verificar "GET /perguntas sem token é negado" "401|403" "$(requisicao GET "$API_URL/perguntas")"
echo

echo "4) Cadastro e login (grava e lê no MySQL)"
EMAIL="smoke.$(date +%s).$RANDOM@example.com"
SENHA="SenhaSmoke123"

verificar "POST /auth/register" "201" \
  "$(requisicao POST "$API_URL/auth/register" "{\"nome\":\"Smoke Test\",\"email\":\"$EMAIL\",\"senha\":\"$SENHA\"}")"
verificar "POST /auth/register com e-mail repetido" "409" \
  "$(requisicao POST "$API_URL/auth/register" "{\"nome\":\"Smoke Test\",\"email\":\"$EMAIL\",\"senha\":\"$SENHA\"}")"
verificar "POST /auth/login com senha errada" "401" \
  "$(requisicao POST "$API_URL/auth/login" "{\"email\":\"$EMAIL\",\"senha\":\"senha-errada\"}")"
verificar "POST /auth/login" "200" \
  "$(requisicao POST "$API_URL/auth/login" "{\"email\":\"$EMAIL\",\"senha\":\"$SENHA\"}")"

TOKEN="$(extrair_token)"
if [ -z "$TOKEN" ]; then
  echo "  [FALHA] O login não retornou um token."
  exit 1
fi
echo

echo "5) Rotas autenticadas"
verificar "GET /perguntas com token" "200" "$(requisicao GET "$API_URL/perguntas" "" "$TOKEN")"
PERGUNTAS="$(cat "$CORPO")"
verificar "GET /avaliacoes/ultima sem avaliações" "204" \
  "$(requisicao GET "$API_URL/avaliacoes/ultima" "" "$TOKEN")"

if command -v jq >/dev/null 2>&1; then
  RESPOSTAS="$(printf '%s' "$PERGUNTAS" | jq -c '{respostas: [.[] | {perguntaId: .id, opcaoId: .opcoes[0].id}]}')"
  verificar "POST /avaliacoes (grava no MySQL)" "201" \
    "$(requisicao POST "$API_URL/avaliacoes" "$RESPOSTAS" "$TOKEN")"
  verificar "GET /avaliacoes/ultima após criar" "200" \
    "$(requisicao GET "$API_URL/avaliacoes/ultima" "" "$TOKEN")"
  verificar "GET /avaliacoes" "200" "$(requisicao GET "$API_URL/avaliacoes" "" "$TOKEN")"
else
  echo "  [AVISO] jq não encontrado: etapa de criação de avaliação ignorada."
fi
echo

if [ "$falhas" -gt 0 ]; then
  echo "Smoke test FALHOU ($falhas verificação(ões) com erro)."
  exit 1
fi
echo "Smoke test OK."
