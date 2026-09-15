---
description: Créer un content type de A à Z, du dev local jusqu'au déploiement Heroku
---

# Créer un nouveau content type

Content type demandé : **$ARGUMENTS**

> ⚠️ Le Content-Type Builder est **désactivé en production**. Un schéma ne peut
> exister en prod que s'il a été créé en local, commité, puis déployé. Il n'y a
> aucun raccourci.

---

## Étape 1 — Démarrer l'environnement local

```bash
npm run db:status   # Postgres répond ?
npm run dev:start   # sinon : démarre Docker + Strapi en mode develop
```

**Point de vérification** : l'admin répond sur http://localhost:1337/admin et le
menu *Content-Type Builder* est visible dans la barre latérale. S'il est absent,
`NODE_ENV` est à `production` en local — corrige `.env` avant de continuer.

---

## Étape 2 — Créer le schéma dans l'admin

Content-Type Builder → *Create new collection type* (ou *single type*).

À décider avant de cliquer, parce que c'est pénible à changer après :

- **Display name au singulier** (`Article`, pas `Articles`) — Strapi dérive les
  pluriels et les routes tout seul.
- **Draft & Publish** : activé si le contenu doit être relu avant mise en ligne.
- **Internationalization** : activé seulement si le multilingue est prévu.
- Les champs relationnels : créer d'abord les content types cibles.

Strapi redémarre à chaque sauvegarde. Attendre le rechargement complet.

**Point de vérification** : le fichier existe et est lisible.

```bash
cat src/api/<name>/content-types/<name>/schema.json
```

---

## Étape 3 — Vérifier les fichiers générés

```bash
git status --short src/api src/components types/generated
```

Strapi doit avoir créé :

```
src/api/<name>/content-types/<name>/schema.json   ← la définition
src/api/<name>/controllers/<name>.ts
src/api/<name>/routes/<name>.ts
src/api/<name>/services/<name>.ts
types/generated/contentTypes.d.ts                 ← régénéré
```

Plus `src/components/<category>/<component>.json` si des composants ont été créés.

**Point de vérification** : si `schema.json` n'apparaît pas, la sauvegarde dans
l'admin n'a pas abouti — recommencer l'étape 2.

---

## Étape 4 — Ouvrir les permissions

Settings → Users & Permissions → Roles → **Public** (ou *Authenticated*) →
cocher `find` / `findOne` sur le nouveau content type → Save.

Sans ça l'API renvoie **403** même si le content type existe.

**Point de vérification** :

```bash
curl -s http://localhost:1337/api/<pluriel> | head -c 400
```

Attendu : `{"data":[],"meta":{...}}`. Un `403` = permissions non enregistrées.

---

## Étape 5 — Tester avec une entrée réelle

Créer une entrée dans Content Manager, la publier si Draft & Publish est actif,
puis relancer le `curl` ci-dessus.

**Point de vérification** : la réponse contient un **`documentId`** (chaîne
alphanumérique). En Strapi 5 c'est l'identifiant à utiliser côté client, pas le
`id` numérique. Pour du code serveur, l'accès passe par le Document Service :

```ts
await strapi.documents('api::<name>.<name>').findMany({ status: 'published' });
```

`strapi.entityService` est l'API de la v4 et ne doit pas être utilisée.

---

## Étape 6 — Commiter

```bash
git add src/api src/components types/generated
git status --short          # relire ce qui part vraiment
git commit -m "feat(content-type): ajoute <name>"
git push origin master
```

**Point de vérification** : `git status --short src/api src/components` ne
renvoie plus rien.

---

## Étape 7 — Déployer

```bash
npm run predeploy     # bloque si quoi que ce soit manque
npm run prod:deploy
```

Ou directement `/deploy`.

**Point de vérification final**, une fois le déploiement terminé :

```bash
npm run prod:health                                    # 204 attendu
curl -s "$(heroku apps:info -a mon-strapi-cms --json \
  | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).app.web_url')api/<pluriel>"
```

Le content type existe en prod mais **sa table est vide** : le schéma voyage avec
le code, pas le contenu. Pour y pousser des données, voir `scripts/sync-content.sh`.

---

## Pièges fréquents

| Symptôme | Cause |
|---|---|
| 404 sur l'API en prod | schéma non commité — refaire l'étape 6 |
| 403 sur l'API en prod | permissions à réouvrir dans l'admin **de prod** (elles sont en base, pas dans le code) |
| Content type visible, table vide | normal — le contenu ne se déploie pas avec le code |
| Build Heroku KO après ajout | relation vers un content type inexistant, ou composant non commité |
