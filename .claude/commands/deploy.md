---
description: Déployer sur Heroku — predeploy-check, push, suivi des logs, vérification du /_health
---

# Déployer sur Heroku

Cible : app **mon-strapi-cms**, branche **master**, remote **heroku**.

---

## 1. Pré-vol

```bash
npm run predeploy
```

Six gardes-fous. En cas d'échec, le script affiche la commande exacte de
correction — l'appliquer et relancer. **Ne pas contourner avec `SKIP_BUILD=1`**
pour un vrai déploiement : c'est réservé au debug du script lui-même.

Rappel de ce qui bloque :

| Blocage | Pourquoi c'est bloquant |
|---|---|
| Schéma/config non commité | le Content-Type Builder est désactivé en prod, le code est la seule source |
| Branche en retard sur `origin/master` | déployer écraserait le travail des autres |
| `pg` hors `dependencies` | Heroku n'installe pas les devDependencies → crash au boot |
| Variable d'env manquante | l'app démarre puis crashe, ou tombe sur SQLite |
| `npm run build` KO | le build Heroku échouerait de la même façon, 5 minutes plus tard |

---

## 2. Déployer

```bash
npm run prod:deploy
```

Équivaut à `npm run predeploy && git push heroku master`.

Le buildpack Node de Heroku enchaîne : `npm ci` → `npm run build` → démarrage via
`npm start`. Compter 3 à 6 minutes.

Pendant le push, surveiller la sortie : `remote: -----> Build succeeded!` puis
`remote: Verifying deploy... done.`

---

## 3. Suivre les logs

Dans un second terminal, **avant** la fin du build :

```bash
npm run prod:logs
```

Ce qu'il faut voir passer :

```
State changed from starting to up
Strapi started successfully
http://0.0.0.0:<port>/admin
```

Signaux d'alarme :

| Log | Diagnostic |
|---|---|
| `Error: connect ECONNREFUSED` | add-on Postgres non attaché ou `DATABASE_SSL` absent |
| `Cannot find module 'pg'` | `pg` en devDependencies |
| `error: no pg_hba.conf entry` | `DATABASE_SSL=true` manquant |
| `Missing apiToken.salt` | `API_TOKEN_SALT` non défini |
| `H10 App crashed` | lire les 50 lignes au-dessus, la vraie erreur y est |
| `R14 Memory quota exceeded` | dyno trop petit pour le build Strapi |

Ctrl-C pour arrêter le suivi.

---

## 4. Vérifier la santé

```bash
npm run prod:health   # 204 attendu
npm run prod:ps       # le dyno web doit être "up"
```

`/_health` répond **204 No Content** quand l'app a démarré. Tout autre code (ou
un timeout) signifie que le dyno n'est pas opérationnel — retourner aux logs.

---

## 5. Vérification fonctionnelle

```bash
npm run prod:open     # ouvre l'app dans le navigateur
```

À contrôler dans l'admin de prod :

- connexion au panneau admin (si elle échoue, `ADMIN_JWT_SECRET` a peut-être changé — les sessions sont invalidées, se reconnecter suffit)
- le *Content-Type Builder* est bien **absent** — c'est le comportement attendu
- Media Library : les miniatures s'affichent (sinon → CSP ou Cloudinary, voir `/debug-prod`)
- les nouveaux content types apparaissent dans Content Manager

---

## En cas d'échec du déploiement

```bash
npm run prod:logs        # 1. lire l'erreur réelle
heroku releases -a mon-strapi-cms   # 2. lister les releases
```

Rollback vers la release précédente :

```bash
heroku releases:rollback -a mon-strapi-cms
```

⚠️ Le rollback restaure **le code**, pas la base. Une migration de schéma déjà
appliquée reste en place.

Pour un diagnostic complet : `/debug-prod`.
