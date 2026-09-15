---
description: Checklist de diagnostic de la production Heroku — logs, dyno, Postgres, variables d'env
---

# Diagnostiquer la production

Symptôme observé : **$ARGUMENTS**

App : `mon-strapi-cms`. Dérouler dans l'ordre — chaque étape élimine une famille
de causes. **Ne pas sauter directement à l'étape qui semble la bonne.**

---

## 1. L'app répond-elle ?

```bash
npm run prod:health   # 204 = OK
npm run prod:ps       # état des dynos
```

| Résultat | Direction |
|---|---|
| `204` | l'app tourne → le problème est applicatif, aller en 4 et 5 |
| `503` / timeout | dyno down ou en crash-loop → étape 2 |
| `403` / `404` | l'app tourne, c'est une route ou une permission → étape 5 |
| dyno `crashed` | étape 2 |
| dyno absent | `heroku ps:scale web=1 -a mon-strapi-cms` |

---

## 2. Logs

```bash
heroku logs -n 200 -a mon-strapi-cms          # instantané
npm run prod:logs                              # suivi continu
heroku logs -n 500 -a mon-strapi-cms | grep -iE 'error|fatal|crash|H1[0-9]|R1[0-9]'
```

Erreurs de démarrage et cause :

| Log | Cause | Correction |
|---|---|---|
| `Cannot find module 'pg'` | `pg` en devDependencies | `npm uninstall pg && npm install pg`, commiter, redéployer |
| `ECONNREFUSED` / `ENOTFOUND` | pas d'add-on Postgres | étape 3 |
| `no pg_hba.conf entry ... no encryption` | SSL non activé | `heroku config:set DATABASE_SSL=true DATABASE_SSL_REJECT_UNAUTHORIZED=false -a mon-strapi-cms` |
| `self signed certificate` | certificat Heroku rejeté | `heroku config:set DATABASE_SSL_REJECT_UNAUTHORIZED=false -a mon-strapi-cms` |
| `Missing apiToken.salt` / `Missing admin.auth.secret` | variable absente | étape 4 |
| `Middleware "strapi::security": App keys are required` | `APP_KEYS` absent ou mal formaté (liste CSV) | étape 4 |
| `H10 App crashed` | code générique | lire les lignes **précédentes**, la vraie erreur est au-dessus |
| `H14 No web dynos running` | pas de dyno | `heroku ps:scale web=1 -a mon-strapi-cms` |
| `R14 Memory quota exceeded` | build/runtime trop lourd | passer à un dyno supérieur |
| `H12 Request timeout` | requête > 30s | étape 3, connexions saturées |

---

## 3. Postgres

```bash
npm run prod:pg                      # connexions, taille, version
heroku pg:diagnose -a mon-strapi-cms # rapport automatique
```

À regarder :

- **Connections** : proche de la limite du plan (20 sur `essential-0`) → le pool
  Strapi est trop large. `heroku config:set DATABASE_POOL_MAX=5 -a mon-strapi-cms`.
  Chaque dyno ouvre son propre pool : `dynos × DATABASE_POOL_MAX` doit rester
  sous la limite.
- **Data Size** : proche du quota → écritures bloquées.
- **Status** : `available` attendu.

Connexions bloquées :

```bash
heroku pg:ps -a mon-strapi-cms          # requêtes en cours
heroku pg:killall -a mon-strapi-cms     # ⚠️ tue toutes les connexions
```

L'add-on est-il seulement attaché ?

```bash
heroku addons -a mon-strapi-cms
```

Sans add-on, `DATABASE_URL` est absente et Strapi retombe sur SQLite : l'app
démarre, paraît saine, et **perd toutes les données à chaque redémarrage**.

---

## 4. Variables d'environnement

```bash
heroku config -a mon-strapi-cms | cut -d: -f1   # noms seuls, sans les valeurs
```

Doivent être présentes :

```
DATABASE_URL          (injectée par l'add-on, jamais définie à la main)
DATABASE_CLIENT=postgres
DATABASE_SSL=true
DATABASE_SSL_REJECT_UNAUTHORIZED=false
APP_KEYS
ADMIN_JWT_SECRET
JWT_SECRET
API_TOKEN_SALT
TRANSFER_TOKEN_SALT
ENCRYPTION_KEY
CLOUDINARY_NAME / CLOUDINARY_KEY / CLOUDINARY_SECRET
NODE_ENV=production
```

Contrôle automatique des 7 variables critiques, sans afficher aucune valeur :

```bash
npm run predeploy     # étape 5 du script
```

> Modifier une variable redémarre le dyno. Changer `ADMIN_JWT_SECRET` ou
> `APP_KEYS` **déconnecte tous les admins** — se reconnecter suffit, rien n'est perdu.

---

## 5. Problèmes applicatifs (l'app répond mais se comporte mal)

### Médias absents ou miniatures cassées

```bash
heroku config -a mon-strapi-cms | grep -c CLOUDINARY   # attendu : 3
```

- **Uploads qui disparaissent après un redémarrage** → le provider `local` est
  actif en prod. Vérifier `NODE_ENV=production` et les 3 variables Cloudinary.
- **Fichiers uploadés mais miniatures blanches dans l'admin** → CSP. Vérifier que
  `config/middlewares.ts` contient bien `res.cloudinary.com` dans `img-src` et
  `media-src`, et que le fichier est **commité et déployé**. Confirmer dans la
  console du navigateur : une erreur `Refused to load the image` = CSP.
- **Anciens médias 404** → uploadés avant la bascule Cloudinary, ils étaient sur
  le FS éphémère et sont définitivement perdus. À ré-uploader.

### Content type absent en prod

```bash
git log --oneline -5 -- src/api
git status --short src/api src/components
```

Schéma non commité ou non déployé → `/new-content-type`, étape 6.

### API en 403

Les permissions vivent **en base de données**, pas dans le code : elles ne se
déploient pas. Les ouvrir dans l'admin **de prod** : Settings → Users &
Permissions → Roles → Public → cocher `find`/`findOne` → Save.

### Admin inaccessible

- `ADMIN_JWT_SECRET` modifié récemment → sessions invalidées, se reconnecter.
- Mot de passe oublié :
  `heroku run npm run strapi admin:reset-user-password -- --email <email> -a mon-strapi-cms`

---

## 6. Inspection directe

```bash
npm run prod:console                                  # console Strapi sur un dyno one-off
heroku run bash -a mon-strapi-cms                     # shell
heroku pg:psql -a mon-strapi-cms                      # psql sur la base de prod
```

Dans la console Strapi (API v5, Document Service) :

```js
await strapi.documents('api::article.article').count()
await strapi.documents('api::article.article').findMany({ limit: 3 })
```

---

## 7. Revenir en arrière

```bash
heroku releases -a mon-strapi-cms
heroku releases:rollback -a mon-strapi-cms          # release précédente
heroku releases:rollback v42 -a mon-strapi-cms      # release ciblée
```

⚠️ Le rollback ne restaure **que le code**. Les données et les migrations déjà
appliquées restent en l'état. Pour restaurer la base :

```bash
heroku pg:backups -a mon-strapi-cms
heroku pg:backups:restore <id> DATABASE_URL -a mon-strapi-cms   # ⚠️ destructif
```

---

## Récapitulatif

```bash
npm run prod:ps && npm run prod:health   # 1. l'app tourne ?
heroku logs -n 200 -a mon-strapi-cms     # 2. que dit-elle ?
npm run prod:pg                          # 3. la base va bien ?
npm run predeploy                        # 4. les variables sont là ?
```
