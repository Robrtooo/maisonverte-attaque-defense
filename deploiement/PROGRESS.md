# MaisonVerte — Etat d'avancement des scripts de deploiement

Fichier de reprise, tenu a jour a chaque point d'arret. Contrairement au
ledger `.superpowers/sdd/PLAN/progress.md` (local, non versionne, sert de
scratch pendant une session), ce fichier EST versionne : c'est la source de
verite pour reprendre le travail depuis n'importe quelle machine.

Derniere mise a jour : 15/09/2026, session interrompue par une limite
d'usage cote assistant. Reprise volontaire a un point de coupure propre.

## Comment reprendre

1. `git fetch origin && git worktree add .worktrees/deployment-scripts -b feat/deployment-scripts origin/feat/deployment-scripts` (ou `git checkout feat/deployment-scripts` si pas de worktree existant).
2. Lire `deploiement/ARCHITECTURE.md` puis `deploiement/PLAN.md` (le plan en 9 taches, format checklist, prevu pour etre execute avec le skill `superpowers:subagent-driven-development`).
3. Si vous avez le skill Superpowers disponible : invoquez `superpowers:subagent-driven-development` sur `deploiement/PLAN.md`, il recree son propre ledger de travail (`.superpowers/sdd/PLAN/progress.md`, gitignore, normal qu'il n'existe pas au depart sur une machine neuve) et reprend a la Task 3 (les Tasks 1 et 2 sont fermees, ne pas les redispatcher).
4. Sinon : reprendre manuellement a la Task 3 telle que decrite ci-dessous.

## Etat exact

- **Branche** : `feat/deployment-scripts`, remote `git@github.com:Robrtooo/maisonverte-attaque-defense.git` (le push HTTPS echoue sur cette machine faute de credential — utiliser SSH ou `gh auth login` si vous reprenez ailleurs).
- **Task 1 (socle commun)** : ferme, revu (1 tour de correctifs), pousse. Commits `88b412d..8be5bba`.
- **Task 2 (reseaux/TLS/offline/OPNsense)** : ferme, revu (1 tour de correctifs), pousse. Commits `8be5bba..6b7df9a`.
- **Task 3 (services DMZ E2-E5)** : **EN COURS, interrompue volontairement en phase RED.**
  - Un seul fichier existe : `deploiement/tests/static/test-dmz.sh` (test statique attendu-en-echec, TDD step 1), pas encore verifie comme etant reellement en echec, pas encore implemente.
  - Aucun `install-eX-*.sh`, aucun `compose.yaml` de service DMZ n'existe encore.
  - Rien n'est commite pour cette tache au moment de la redaction de ce fichier (un commit WIP explicite a ete demande a l'agent implementeur en cours de route — verifier `git log --oneline -5` sur la branche pour voir si ce commit WIP existe; s'il existe son message commence par `wip(task-3):`).
- **Tasks 4 a 9** : non commencees.

## Point ouvert a trancher en reprenant la Task 3

`ARCHITECTURE.md` liste 4 hotes publics tous routes par E2 sur le seul port 443
("E2 preserve les methodes, URI, corps et en-tetes necessaires aux exploits
de E3 et E5"), ce qui suggere que E2 fait aussi office de reverse-proxy pour
E5 (`vendeurs.maisonverte.fr`), pas seulement pour E3/E4. Un brouillon plus
ancien de PLAN.md semblait sous-entendre que seuls E3/E4 passaient par E2.
**Trancher en faveur d'ARCHITECTURE.md** (le document qui fait autorite) :
E2 route bien vers E3, E4 ET E5. E3/E4/E5 ne publient aucun port hote — seul
E2 publie `192.168.10.50:443:443`.

## Regles deja tranchees a ne pas re-discuter

- `create-networks.sh` (Task 2) cree les 6 reseaux de zone + les 9
  micro-segments de chaine (15 reseaux externes au total). Les reseaux
  prives par service (ex. `mv-e3-db` pour WordPress/MySQL) sont declares
  DANS le compose.yaml de chaque service, pas ici.
- Noms de reseaux exacts (fixes par Task 2, a reutiliser tels quels) :
  `net-dmz`, `net-srv`, `net-data`, `net-users`, `net-admin`, `net-spec`,
  `mv-a-edge`, `mv-a-core`, `mv-a-data`, `mv-b-edge`, `mv-b-core`,
  `mv-b-data`, `mv-c-edge`, `mv-c-core`, `mv-c-spec`.
- `deploiement/config/flags.map` (Task 1) : ordre des flag_id fixe a
  E2=1, E3=2, E5=3, E7=4, E8=5, E10=6, E14=7, E12=8, E11=9, E6=10, E9=11,
  E13=12 (ordre N1 puis chaines A/B/C dans leur ordre de pivot).
- Sous-reseaux des 9 micro-segments (172.31.x.0/28, alloues par Task 2) :
  choix interne arbitraire, sans source amont, documente dans
  `create-networks.sh` — ne pas les re-questionner sauf collision reelle
  constatee.
- Snapshot Vulhub vendu dans `deploiement/vendor/vulhub/` au commit exact
  `aeaf65793f147f29bd50841ef77f4e9cad07ecc7` (Task 1) — ne pas re-cloner,
  la copie est deja mecanique et complete pour les 12 scenarios retenus.

## Methode a suivre (deja appliquee sur Tasks 1-2, a repeter)

Un agent implementeur par tache (`superpowers:subagent-driven-development`),
puis un agent reviewer independant (spec + qualite), boucle de correctifs
si besoin (max 5 tours, reprise du meme implementeur pour les 3 premiers),
puis push seulement apres revue propre. Aucune execution reelle sur le lab
avant la revue finale de toute la branche (Task 9 terminee).
