#!/usr/bin/env bash
# Certificado local de assinatura de código, compartilhado pela família Ronic (mesmo keychain
# usado pelo Ronic Mirror). Criado uma única vez; depois só é reutilizado.
#
# Por quê: o macOS amarra a permissão de Acessibilidade à assinatura do app. Com assinatura
# ad-hoc, cada recompilação vira um "app diferente": a chave em Ajustes continua ligada, mas
# não vale para o binário novo. Assinando sempre com o MESMO certificado, o requisito vira
# `identifier "…" and certificate leaf = H"…"` e a permissão sobrevive às recompilações.
#
# Fica num keychain próprio em ~/.ronic-mirror-signing (fora do repositório). Não mexe no
# keychain de login nem marca nada como confiável no sistema.
# Saída (stdout): o hash SHA-1 da identidade, para `codesign --sign <hash>`.
set -euo pipefail

DIR="$HOME/.ronic-mirror-signing"
KC="$DIR/ronic-signing.keychain-db"
PASS="ronic-mirror-local"
NAME="Ronic Mirror Local Signing"

mkdir -p "$DIR"
chmod 700 "$DIR"

if [[ ! -f "$KC" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$TMP/cert.cnf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1
  /usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -out "$TMP/id.p12" -passout "pass:$PASS" >/dev/null 2>&1

  security create-keychain -p "$PASS" "$KC" >/dev/null
  security set-keychain-settings "$KC"            # sem bloqueio automático
  security unlock-keychain -p "$PASS" "$KC"
  security import "$TMP/id.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KC" >/dev/null
fi

security unlock-keychain -p "$PASS" "$KC"

# Garante que o keychain está na lista de busca do usuário (exigência do codesign).
current=$(security list-keychains -d user | sed 's/^ *"//; s/"$//')
if ! grep -qxF "$KC" <<<"$current"; then
  # shellcheck disable=SC2086
  security list-keychains -d user -s $current "$KC"
fi

security find-identity -p codesigning "$KC" | awk -v n="\"$NAME\"" '$0 ~ n {print $2; exit}'
