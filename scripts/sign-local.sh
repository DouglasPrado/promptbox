#!/bin/bash
#
# Assina o Promptbox com uma identidade local estável.
#
# Por que isso existe: sem certificado, o Xcode assina o app em modo ad-hoc e cada
# build vira uma identidade diferente para o macOS. A permissão de Acessibilidade
# é amarrada à assinatura, então ela cai a cada compilação — o item continua
# marcado em Ajustes do Sistema, mas aponta para o binário anterior.
#
# Com um certificado próprio, a identidade para de mudar e a autorização persiste.
#
# Uso:  ./scripts/sign-local.sh [caminho/para/Promptbox.app]
#
# Para desfazer:
#   security delete-keychain ~/Library/Keychains/promptbox-signing.keychain-db
#   tccutil reset Accessibility com.oialbert.promptbox

set -euo pipefail

APP="${1:-build/Promptbox.app}"
KEYCHAIN="$HOME/Library/Keychains/promptbox-signing.keychain-db"
KEYCHAIN_SHORT="promptbox-signing.keychain"
KEYCHAIN_PASSWORD="promptbox-local"
IDENTITY="Promptbox Local Signing"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [ ! -d "$APP" ]; then
  echo "App não encontrado em: $APP" >&2
  exit 1
fi

if ! security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "==> Criando identidade de assinatura local"

  cat > "$WORKDIR/openssl.cnf" <<'CONF'
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no

[ dn ]
CN = Promptbox Local Signing

[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF

  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" \
    -config "$WORKDIR/openssl.cnf" >/dev/null 2>&1

  # Algoritmos legados e senha não vazia: o `security import` do macOS recusa o
  # MAC padrão do OpenSSL 3.
  openssl pkcs12 -export -macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES \
    -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
    -out "$WORKDIR/identity.p12" -passout pass:"$KEYCHAIN_PASSWORD" \
    -name "$IDENTITY" >/dev/null 2>&1

  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN" 2>/dev/null || true
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security set-keychain-settings "$KEYCHAIN"

  security import "$WORKDIR/identity.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

  # Libera o uso da chave pelo codesign sem diálogo a cada assinatura.
  security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null 2>&1

  # Mantém o chaveiro na lista de busca, preservando os já existentes.
  EXISTING=$(security list-keychains -d user | tr -d '"' | tr -d ' ')
  if ! echo "$EXISTING" | grep -q "$KEYCHAIN_SHORT"; then
    # shellcheck disable=SC2086
    security list-keychains -d user -s $EXISTING "$KEYCHAIN"
  fi
else
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
fi

echo "==> Assinando $APP"
codesign --force --deep --sign "$IDENTITY" --keychain "$KEYCHAIN" "$APP"

echo "==> Assinatura resultante"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "Identifier|Authority|Signature" || true

echo
echo "Pronto. Autorize o app em Ajustes do Sistema → Privacidade e Segurança →"
echo "Acessibilidade. A autorização passa a sobreviver aos próximos builds,"
echo "desde que você rode este script depois de cada build."
