#!/usr/bin/env bash
#
# predeploy-check.sh — garde-fou avant `git push heroku master`.
#
# Bloque le deploiement tant que les conditions structurelles d'un Strapi sur
# Heroku ne sont pas reunies. Chaque echec affiche la commande exacte a lancer.
#
# Usage :
#   npm run predeploy
#   GIT_REMOTE=origin GIT_BRANCH=master npm run predeploy
#   SKIP_BUILD=1 npm run predeploy        # iteration rapide, a eviter avant un vrai push
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-master}"
HEROKU_APP="${HEROKU_APP:-${npm_package_config_heroku_app:-mon-strapi-cms}}"

# Chemins dont un changement non commite casse la prod :
#  - src/api, src/components : le Content-Type Builder etant desactive en
#    production, ces fichiers sont la SEULE source de verite des schemas.
#  - config : la config applicative voyage avec le code.
#  - package.json / package-lock.json : Heroku lance `npm ci` depuis le LOCKFILE
#    COMMITE. Une dependance installee en local mais non commitee produit un
#    build casse ou un crash au boot, jamais une erreur locale.
WATCHED_PATHS=(src/api src/components config package.json package-lock.json)

REQUIRED_HEROKU_VARS=(
  DATABASE_CLIENT
  DATABASE_SSL
  APP_KEYS
  ADMIN_JWT_SECRET
  JWT_SECRET
  API_TOKEN_SALT
  TRANSFER_TOKEN_SALT
)

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

FAILURES=0
STEP=0

step()  { STEP=$((STEP + 1)); printf '\n%s[%d/6]%s %s\n' "$BLUE" "$STEP" "$RESET" "$1"; }
ok()    { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()  { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail()  {
  FAILURES=$((FAILURES + 1))
  printf '  %s✗ %s%s\n' "$RED" "$1" "$RESET"
}
fix()   { printf '    %s→ %s%s\n' "$BOLD" "$1" "$RESET"; }

printf '%s=== Pre-deploy check — %s ===%s\n' "$BOLD" "$HEROKU_APP" "$RESET"

# ---------------------------------------------------------------------------
# 1. Outils requis
# ---------------------------------------------------------------------------
step "Outils requis"
for tool in git node npm; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool present"
  else
    fail "$tool introuvable dans le PATH"
    fix "installe $tool avant de continuer"
  fi
done
if command -v heroku >/dev/null 2>&1; then
  ok "heroku CLI present"
  HEROKU_AVAILABLE=1
else
  fail "heroku CLI introuvable — impossible de verifier les variables de prod"
  fix "curl https://cli-assets.heroku.com/install.sh | sh"
  HEROKU_AVAILABLE=0
fi

# ---------------------------------------------------------------------------
# 2. Schemas et config non commites
# ---------------------------------------------------------------------------
step "Schemas, config et dependances non commites"
DIRTY="$(git status --porcelain --untracked-files=all -- "${WATCHED_PATHS[@]}")"
if [[ -n "$DIRTY" ]]; then
  fail "des fichiers embarques par le deploiement ne sont pas commites :"
  while IFS= read -r line; do
    printf '      %s\n' "$line"
  done <<< "$DIRTY"
  printf '\n'
  fix "git add ${WATCHED_PATHS[*]} types/generated"
  fix "git commit -m \"<type>(<scope>): <description>\""

  # Les consequences different selon ce qui a change : on n'affiche que le
  # rappel reellement pertinent, sinon il devient du bruit qu'on cesse de lire.
  if grep -qE '(src/api|src/components)' <<< "$DIRTY"; then
    printf '\n    %sSchemas : le Content-Type Builder est desactive en production.%s\n' "$YELLOW" "$RESET"
    printf '    %sUn schema absent du commit ne sera jamais deploye.%s\n' "$YELLOW" "$RESET"
  fi
  if grep -qE 'package(-lock)?\.json' <<< "$DIRTY"; then
    printf '\n    %sDependances : Heroku lance `npm ci` depuis le lockfile commite.%s\n' "$YELLOW" "$RESET"
    printf '    %sUn paquet installe en local mais absent du commit fera crasher le dyno.%s\n' "$YELLOW" "$RESET"
  fi
else
  ok "schemas, config et dependances sont propres"
fi

# Les types generes ne bloquent pas le deploiement (ils sont regeneres au build)
# mais un oubli rend les diffs illisibles pour l'equipe.
TYPES_DIRTY="$(git status --porcelain --untracked-files=all -- types/generated 2>/dev/null || true)"
if [[ -n "$TYPES_DIRTY" ]]; then
  warn "types/generated a change et n'est pas commite (non bloquant)"
  fix "git add types/generated && git commit --amend --no-edit"
fi

# ---------------------------------------------------------------------------
# 3. Synchronisation avec le depot distant
# ---------------------------------------------------------------------------
step "Synchronisation avec $GIT_REMOTE/$GIT_BRANCH"
if ! git remote get-url "$GIT_REMOTE" >/dev/null 2>&1; then
  fail "le remote '$GIT_REMOTE' n'existe pas"
  fix "git remote add $GIT_REMOTE <url-du-depot>"
  fix "ou relance avec : GIT_REMOTE=<autre> npm run predeploy"
else
  if ! git fetch --quiet "$GIT_REMOTE" "$GIT_BRANCH" 2>/dev/null; then
    fail "impossible de recuperer $GIT_REMOTE/$GIT_BRANCH"
    fix "git fetch $GIT_REMOTE $GIT_BRANCH   # verifie l'acces reseau et tes droits"
  else
    BEHIND="$(git rev-list --count "HEAD..$GIT_REMOTE/$GIT_BRANCH")"
    AHEAD="$(git rev-list --count "$GIT_REMOTE/$GIT_BRANCH..HEAD")"
    if [[ "$BEHIND" -gt 0 ]]; then
      fail "branche locale en retard de $BEHIND commit(s) sur $GIT_REMOTE/$GIT_BRANCH"
      fix "git pull --rebase $GIT_REMOTE $GIT_BRANCH"
      printf '    %sDeployer maintenant ecraserait le travail des autres.%s\n' "$YELLOW" "$RESET"
    else
      ok "a jour avec $GIT_REMOTE/$GIT_BRANCH"
    fi
    if [[ "$AHEAD" -gt 0 ]]; then
      warn "$AHEAD commit(s) local(aux) pas encore pousse(s) sur $GIT_REMOTE"
      fix "git push $GIT_REMOTE $GIT_BRANCH   # a faire avant ou apres le deploiement"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4. `pg` en dependance de production
# ---------------------------------------------------------------------------
step "Driver Postgres dans les dependencies"
# Heroku n'installe pas les devDependencies : `pg` en devDependencies produit un
# crash au boot du dyno (`Cannot find module 'pg'`), pas une erreur de build.
PG_LOCATION="$(node -e '
  const p = require("./package.json");
  if (p.dependencies && p.dependencies.pg) process.stdout.write("dependencies:" + p.dependencies.pg);
  else if (p.devDependencies && p.devDependencies.pg) process.stdout.write("devDependencies:" + p.devDependencies.pg);
  else process.stdout.write("absent:");
')"
PG_SECTION="${PG_LOCATION%%:*}"
PG_VERSION="${PG_LOCATION#*:}"
case "$PG_SECTION" in
  dependencies)
    ok "pg@$PG_VERSION en dependencies"
    ;;
  devDependencies)
    fail "pg@$PG_VERSION est en devDependencies — Heroku ne l'installera pas"
    fix "npm uninstall pg && npm install pg"
    ;;
  *)
    fail "pg est absent du package.json"
    fix "npm install pg"
    ;;
esac

# ---------------------------------------------------------------------------
# 5. Variables d'environnement sur Heroku
# ---------------------------------------------------------------------------
step "Variables d'environnement sur Heroku ($HEROKU_APP)"
if [[ "$HEROKU_AVAILABLE" -eq 0 ]]; then
  warn "verification ignoree (heroku CLI absent)"
else
  # --json ne sort que les noms vers ce script : les valeurs ne sont jamais
  # imprimees ni stockees, seules les cles manquantes sont remontees.
  if ! HEROKU_CONFIG_JSON="$(heroku config --json --app "$HEROKU_APP" 2>/dev/null)"; then
    fail "impossible de lire la config de l'app '$HEROKU_APP'"
    fix "heroku login"
    fix "heroku config --app $HEROKU_APP   # verifie que le nom de l'app est correct"
  else
    MISSING="$(printf '%s' "$HEROKU_CONFIG_JSON" | node -e '
      let raw = "";
      process.stdin.on("data", (d) => (raw += d));
      process.stdin.on("end", () => {
        const config = JSON.parse(raw || "{}");
        const required = process.argv.slice(1);
        const missing = required.filter((key) => {
          const value = config[key];
          return value === undefined || String(value).trim() === "";
        });
        process.stdout.write(missing.join(" "));
      });
    ' "${REQUIRED_HEROKU_VARS[@]}")"

    if [[ -n "$MISSING" ]]; then
      fail "variables manquantes ou vides sur Heroku : $MISSING"
      for var in $MISSING; do
        case "$var" in
          DATABASE_CLIENT)
            fix "heroku config:set DATABASE_CLIENT=postgres --app $HEROKU_APP" ;;
          DATABASE_SSL)
            fix "heroku config:set DATABASE_SSL=true DATABASE_SSL_REJECT_UNAUTHORIZED=false --app $HEROKU_APP" ;;
          APP_KEYS)
            fix "heroku config:set APP_KEYS=\"\$(node -e 'console.log(Array.from({length:4},()=>require(\"crypto\").randomBytes(16).toString(\"base64\")).join(\",\"))')\" --app $HEROKU_APP" ;;
          *)
            fix "heroku config:set $var=\"\$(openssl rand -base64 32)\" --app $HEROKU_APP" ;;
        esac
      done
    else
      ok "les ${#REQUIRED_HEROKU_VARS[@]} variables requises sont definies (valeurs non affichees)"
    fi

    if printf '%s' "$HEROKU_CONFIG_JSON" | node -pe '!!JSON.parse(require("fs").readFileSync(0,"utf8")).DATABASE_URL' | grep -q true; then
      ok "DATABASE_URL injectee par l'add-on Postgres"
    else
      fail "DATABASE_URL absente — l'add-on Postgres n'est pas attache"
      fix "heroku addons:create heroku-postgresql:essential-0 --app $HEROKU_APP"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 6. Build
# ---------------------------------------------------------------------------
# Place en dernier : c'est l'etape la plus lente, autant echouer vite sur le reste.
step "Build de production"
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  warn "build ignore (SKIP_BUILD=1) — ne pas deployer sans l'avoir valide"
else
  BUILD_LOG="$(mktemp)"
  trap 'rm -f "$BUILD_LOG"' EXIT
  if NODE_ENV=production npm run build >"$BUILD_LOG" 2>&1; then
    ok "npm run build reussi"
  else
    fail "npm run build a echoue"
    printf '\n'
    tail -n 30 "$BUILD_LOG" | sed 's/^/      /'
    printf '\n'
    fix "npm run build   # rejoue le build en local pour le detail complet"
  fi
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
printf '\n'
if [[ "$FAILURES" -eq 0 ]]; then
  printf '%s✓ Pre-deploy check OK — deploiement autorise.%s\n' "$GREEN" "$RESET"
  printf '  %s→ npm run prod:deploy%s\n\n' "$BOLD" "$RESET"
  exit 0
else
  printf '%s✗ Pre-deploy check : %d blocage(s). Deploiement annule.%s\n\n' "$RED" "$FAILURES" "$RESET"
  exit 1
fi
