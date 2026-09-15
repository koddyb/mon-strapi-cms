# CLAUDE.md — cms-headless

CMS headless **Strapi 5.53.0** (TypeScript), Postgres local via Docker, déployé sur
Heroku (app `mon-strapi-cms`).

> **Strapi v5 exclusivement.** Toute réponse basée sur la v4 est une erreur :
> les schémas vivent dans `src/api/<name>/content-types/<name>/schema.json`,
> l'accès aux données passe par le **Document Service** (`strapi.documents('api::x.x')`,
> *jamais* `strapi.entityService`), et l'API REST expose des **`documentId`** (string)
> et non des `id` numériques.

---

## 1. Les deux environnements

| | Développement | Production |
|---|---|---|
| Lancement | `npm run dev:start` | dyno Heroku (`npm start`) |
| Base | Postgres 16 dans Docker (`../compose.yaml`) | add-on Heroku Postgres |
| Connexion | variables `DATABASE_*` de `.env` | `DATABASE_URL` injectée par l'add-on |
| Médias | provider `local` → `public/uploads` | Cloudinary (FS Heroku éphémère) |
| Content-Type Builder | **actif** | **désactivé** (`NODE_ENV=production`) |
| Secrets | fichier `.env` (non versionné) | `heroku config:set` |

`compose.yaml` est dans le **dossier parent**, hors du dépôt : d'où le `-f ../compose.yaml`
dans les scripts npm.

### Variables d'environnement

| Variable | Rôle | Local | Heroku |
|---|---|---|---|
| `DATABASE_CLIENT` | sélectionne le bloc de `config/database.ts` | `postgres` | `postgres` |
| `DATABASE_URL` | chaîne de connexion complète, prioritaire | absent | **auto** (add-on) |
| `DATABASE_HOST/PORT/NAME/USERNAME/PASSWORD` | fallback si pas de `DATABASE_URL` | `localhost` / `5432` / `strapi` ×3 | non requis |
| `DATABASE_SSL` | TLS vers Postgres | `false` | `true` |
| `DATABASE_SSL_REJECT_UNAUTHORIZED` | certificats auto-signés Heroku | — | `false` |
| `APP_KEYS` | signature des sessions (liste CSV) | ✓ | ✓ |
| `ADMIN_JWT_SECRET` | JWT du panneau admin | ✓ | ✓ |
| `JWT_SECRET` | JWT des utilisateurs API | ✓ | ✓ |
| `API_TOKEN_SALT` | hachage des tokens API | ✓ | ✓ |
| `TRANSFER_TOKEN_SALT` | hachage des tokens `strapi transfer` | ✓ | ✓ |
| `ENCRYPTION_KEY` | chiffrement des secrets stockés en base | ✓ | ✓ |
| `CLOUDINARY_NAME/KEY/SECRET` | provider d'upload | inutile | ✓ |
| `NODE_ENV` | bascule local ↔ Cloudinary | `development` | `production` (auto) |

> Régénérer un secret **invalide les sessions et tokens existants**. Un
> `ADMIN_JWT_SECRET` différent entre deux déploiements déconnecte tous les admins.

---

## 2. Règle absolue : schéma en local → commit → push

Le Content-Type Builder est désactivé en production. **Les schémas ne peuvent pas être
créés depuis l'admin Heroku.** Le seul chemin valide :

```
npm run dev:start        # 1. créer le content type dans l'admin local
git add <chemins>        # 2. commiter les fichiers générés
git commit && git push   # 3. pousser sur origin
npm run prod:deploy      # 4. déployer (predeploy-check bloque si étape 2 oubliée)
```

### Chemins à commiter systématiquement

```
src/api/<name>/content-types/<name>/schema.json   # définition du content type
src/api/<name>/controllers/<name>.ts
src/api/<name>/routes/<name>.ts
src/api/<name>/services/<name>.ts
src/components/<category>/<component>.json        # composants
src/extensions/**                                 # surcharges de plugins
types/generated/contentTypes.d.ts                 # types régénérés
types/generated/components.d.ts
database/migrations/**                            # migrations manuelles
config/**                                         # sauf .env
package.json / package-lock.json                  # Heroku fait `npm ci` sur le lockfile
```

Un schéma absent du commit n'existera pas en prod, et les entrées correspondantes
seront **silencieusement inaccessibles**.

---

## 3. Interdits

- **Ne jamais modifier `config/database.ts`.** Le fichier généré gère déjà
  `connectionString: env('DATABASE_URL')` avec fallback sur les variables détaillées.
  Tout besoin passe par une variable d'environnement.
- **Ne jamais commiter `.env`** (déjà dans `.gitignore`). Les secrets de prod se
  définissent avec `heroku config:set`, jamais dans un fichier versionné.
- **Ne jamais synchroniser du contenu par dump SQL.** Utiliser `strapi transfer` /
  `export` / `import`, qui préservent les `documentId` et le schéma.
- **Ne pas compter sur `public/uploads` en prod** : le filesystem du dyno est éphémère,
  tout fichier écrit disparaît au premier redémarrage.
- **Ne pas mettre `pg` en `devDependencies`** : Heroku ne les installe pas, le dyno
  crashe au boot avec `Cannot find module 'pg'`.

---

## 4. Commandes du quotidien

### Développement local

| Commande | Effet |
|---|---|
| `npm run dev:start` | démarre Postgres (attend le healthcheck) puis `strapi develop` |
| `npm run develop` | Strapi seul, si la base tourne déjà |
| `npm run db:up` / `db:down` | démarre / arrête le conteneur Postgres |
| `npm run db:status` | état du conteneur + `pg_isready` |
| `npm run db:psql` | shell `psql` dans le conteneur |
| `npm run db:logs` | logs Postgres en continu |
| `npm run backup` | export horodaté dans `backups/` (non versionné) |

### Déploiement

| Commande | Effet |
|---|---|
| `npm run predeploy` | les 6 gardes-fous, sans rien déployer |
| `npm run prod:deploy` | `predeploy` puis `git push heroku master` |

`predeploy` bloque si : schéma, config ou dépendances non commités · branche en
retard sur `origin/master` · `pg` hors `dependencies` · variable manquante sur
Heroku · build KO.
Chaque échec affiche la commande de correction. `SKIP_BUILD=1` saute le build (debug
uniquement).

### Synchronisation de contenu

Le contenu ne voyage **jamais** avec le code. Il se transfère avec `strapi transfer`,
qui écrase la cible et préserve les `documentId` (un aller-retour ne duplique rien).

| Commande | Effet |
|---|---|
| `npm run sync:pull` | prod → local, écrase la base locale |
| `npm run sync:push` | local → prod, **destructif**, confirmation par le nom de l'app |

Les deux modes archivent l'état local dans `backups/` avant d'agir. Un
`TRANSFER_TOKEN` (admin de prod → Settings → Transfer Tokens, *Full access*) doit
être exporté dans le shell. Les schémas doivent déjà correspondre des deux côtés :
déployer le code **avant** de transférer du contenu.

### Médias

Provider `local` en développement, **Cloudinary en production** — bascule automatique
sur `env('NODE_ENV')` dans `config/plugins.ts`. La CSP de `config/middlewares.ts`
autorise `res.cloudinary.com` en `img-src` et `media-src`, faute de quoi les
miniatures restent blanches dans la Media Library.

Variables requises en prod : `CLOUDINARY_NAME`, `CLOUDINARY_KEY`, `CLOUDINARY_SECRET`.

### Production

| Commande | Effet |
|---|---|
| `npm run prod:logs` | logs du dyno en continu |
| `npm run prod:ps` | état des dynos |
| `npm run prod:health` | code HTTP de `/_health` (204 attendu) |
| `npm run prod:config` | variables d'env (⚠ affiche les valeurs) |
| `npm run prod:pg` | état de la base Heroku (connexions, taille) |
| `npm run prod:console` | console Strapi sur un dyno one-off |

---

## 5. Repères

- **Branche de déploiement : `master`** (pas `main`). Remotes : `origin` (GitHub) et
  `heroku`.
- **Node 24.x**, pinné dans `engines` et `.nvmrc`, aligné local ↔ Heroku.
- Le buildpack Node de Heroku lance `npm run build` automatiquement, puis `npm start`.
- `/_health` répond **204 No Content** quand l'app est démarrée.
