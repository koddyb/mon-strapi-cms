#!/usr/bin/env bash
#
# sync-content.sh — synchronise le contenu entre local et production.
#
#   ./scripts/sync-content.sh pull    # PROD  -> LOCAL
#   ./scripts/sync-content.sh push    # LOCAL -> PROD   (confirmation requise)
#
# ---------------------------------------------------------------------------
# COMPORTEMENT DE `strapi transfer` — a lire avant la premiere utilisation
# ---------------------------------------------------------------------------
#
# 1. LE TRANSFERT ECRASE LA CIBLE. Par defaut la strategie est `restore` :
#    les donnees de la destination sont SUPPRIMEES puis remplacees par celles
#    de la source. Ce n'est pas une fusion. Tout contenu present uniquement
#    sur la cible est perdu.
#
# 2. LES `documentId` SONT PRESERVES. Un aller-retour (pull puis push) ne
#    duplique donc rien : les documents sont reconnus par leur identifiant et
#    non recrees. Les URLs et references restent stables.
#
# 3. LES SCHEMAS DOIVENT CORRESPONDRE. Si un content type existe d'un cote et
#    pas de l'autre, le transfert echoue. Deployer le schema AVANT de pousser
#    du contenu (voir CLAUDE.md, section 2).
#
# 4. LES MEDIAS SUIVENT. Les fichiers sont transferes avec les entrees. En
#    prod ils repartent chez Cloudinary via le provider configure.
#
# 5. LES UTILISATEURS ADMIN NE SONT PAS TRANSFERES. Les comptes du panneau
#    admin et les cles d'API restent propres a chaque environnement.
#
# ---------------------------------------------------------------------------
# PREREQUIS
# ---------------------------------------------------------------------------
#
#   TRANSFER_TOKEN   (requis) Token de transfert genere dans l'admin DE PROD :
#                    Settings > Transfer Tokens > Create new. Type "Full access".
#                    Exporte-le dans ton shell, ne le commite jamais :
#                      export TRANSFER_TOKEN="xxxxx"
#
#   PROD_URL         (optionnel) URL de l'admin de prod. Deduite de
#                    `heroku apps:info` si absente.
#
#   HEROKU_APP       (optionnel) Nom de l'app. Defaut : mon-strapi-cms.
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

HEROKU_APP="${HEROKU_APP:-${npm_package_config_heroku_app:-mon-strapi-cms}}"
BACKUP_DIR="backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()  { printf '%s→%s %s\n' "$BLUE" "$RESET" "$1"; }
ok()    { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()  { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
die()   { printf '%s✗ %s%s\n' "$RED" "$1" "$RESET" >&2; shift || true; for l in "$@"; do printf '  %s→ %s%s\n' "$BOLD" "$l" "$RESET" >&2; done; exit 1; }

usage() {
  cat <<USAGE
Usage : $0 <pull|push>

  pull   PROD -> LOCAL   ecrase la base locale avec le contenu de production
  push   LOCAL -> PROD   ecrase la production avec le contenu local

Variables :
  TRANSFER_TOKEN   (requis)   token de transfert cree dans l'admin de prod
  PROD_URL         (optionnel) sinon deduit de \`heroku apps:info\`
  HEROKU_APP       (optionnel) defaut : mon-strapi-cms
USAGE
}

MODE="${1:-}"
if [[ "$MODE" != "pull" && "$MODE" != "push" ]]; then
  usage >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Prerequis
# ---------------------------------------------------------------------------
if [[ -z "${TRANSFER_TOKEN:-}" ]]; then
  die "TRANSFER_TOKEN n'est pas defini." \
      "Cree un token : admin de prod > Settings > Transfer Tokens > Create new (Full access)" \
      "export TRANSFER_TOKEN=\"<le-token>\""
fi

if [[ -z "${PROD_URL:-}" ]]; then
  command -v heroku >/dev/null 2>&1 || die "heroku CLI absent et PROD_URL non defini." \
      "export PROD_URL=\"https://<ton-app>.herokuapp.com\""
  info "Resolution de l'URL de production via heroku apps:info…"
  WEB_URL="$(heroku apps:info --app "$HEROKU_APP" --json 2>/dev/null \
    | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).app.web_url' 2>/dev/null || true)"
  [[ -n "$WEB_URL" && "$WEB_URL" != "undefined" ]] || die \
      "impossible de resoudre l'URL de l'app '$HEROKU_APP'." \
      "heroku login" \
      "ou : export PROD_URL=\"https://<ton-app>.herokuapp.com\""
  PROD_URL="${WEB_URL%/}"
fi

# `strapi transfer` attend l'endpoint /admin, pas la racine du site.
REMOTE_ENDPOINT="${PROD_URL%/}/admin"

# ---------------------------------------------------------------------------
# Sauvegarde locale prealable
# ---------------------------------------------------------------------------
# Les deux modes sont destructifs : `pull` ecrase la base locale, `push` ecrase
# la prod. On archive systematiquement l'etat local avant d'agir — c'est le
# seul filet de securite en cas de mauvaise direction.
backup_local() {
  mkdir -p "$BACKUP_DIR"
  local file="$BACKUP_DIR/${MODE}-${TIMESTAMP}"
  info "Sauvegarde locale → ${file}.tar.gz"
  if npx strapi export --no-encrypt --file "$file" >/dev/null 2>&1; then
    ok "Sauvegarde ecrite : ${file}.tar.gz"
  else
    die "l'export local a echoue — transfert annule." \
        "npx strapi export --no-encrypt --file ${file}   # rejoue pour voir l'erreur" \
        "verifie que Postgres tourne : npm run db:status"
  fi
}

# ---------------------------------------------------------------------------
# PULL : prod -> local
# ---------------------------------------------------------------------------
if [[ "$MODE" == "pull" ]]; then
  printf '\n%s=== PULL : PROD → LOCAL ===%s\n\n' "$BOLD" "$RESET"
  info "Source      : $REMOTE_ENDPOINT"
  info "Destination : base locale (Docker)"
  warn "La base LOCALE va etre ecrasee par le contenu de production."
  printf '\n'

  backup_local

  printf '\n'
  info "Transfert en cours…"
  npx strapi transfer \
    --from "$REMOTE_ENDPOINT" \
    --from-token "$TRANSFER_TOKEN" \
    --force

  printf '\n'
  ok "Contenu de production recupere en local."
  info "Relance Strapi : npm run dev:start"
  exit 0
fi

# ---------------------------------------------------------------------------
# PUSH : local -> prod
# ---------------------------------------------------------------------------
printf '\n%s=== PUSH : LOCAL → PROD ===%s\n\n' "$BOLD" "$RESET"
info "Source      : base locale (Docker)"
info "Destination : $REMOTE_ENDPOINT"
printf '\n'
printf '%s%s⚠  OPERATION DESTRUCTIVE SUR LA PRODUCTION%s\n' "$BOLD" "$RED" "$RESET"
printf '%s   Tout le contenu actuellement en production sera SUPPRIME et remplace%s\n' "$RED" "$RESET"
printf '%s   par le contenu de ta base locale. Cette action est irreversible.%s\n\n' "$RED" "$RESET"

printf "Pour confirmer, tape le nom exact de l'app (%s%s%s) : " "$BOLD" "$HEROKU_APP" "$RESET"
read -r CONFIRMATION

if [[ "$CONFIRMATION" != "$HEROKU_APP" ]]; then
  die "confirmation invalide (\"$CONFIRMATION\" ≠ \"$HEROKU_APP\") — transfert annule."
fi

ok "Confirmation acceptee."
printf '\n'

backup_local

printf '\n'
info "Transfert en cours…"
npx strapi transfer \
  --to "$REMOTE_ENDPOINT" \
  --to-token "$TRANSFER_TOKEN" \
  --force

printf '\n'
ok "Contenu local pousse en production."
info "Verifie l'app : npm run prod:health && npm run prod:open"
