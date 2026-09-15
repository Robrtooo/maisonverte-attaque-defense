# MaisonVerte — Etat d'avancement des scripts de deploiement

Fichier de reprise, tenu a jour a chaque point d'arret. Contrairement au
ledger `.superpowers/sdd/PLAN/progress.md` (local, non versionne, sert de
scratch pendant une session), ce fichier EST versionne : c'est la source de
verite pour reprendre le travail depuis n'importe quelle machine.

Derniere mise a jour : 15/09/2026, Task 3 fermee apres relecture independante
et un tour de correctifs. Les validations statiques locales sont vertes ;
aucun script de deploiement ni conteneur n'a ete execute.

Mesure terrain : `vulndb` dispose de 7.95 Gio de RAM, tandis que `poste` et
`nsm` disposent chacun de 3.9 Gio. La DMZ est plafonnee a 1.984 Gio et les
chaines devront etre activees une par une. Le registre local ne contient pas
encore toutes les images requises, notamment WordPress 4.6 et Tomcat 8.5.19.
Le premier deploiement a cree reseaux/TLS et lance E4/E5. E3 a revele puis
corrige un POST d'installation WordPress sans `?step=2`; relancer E3 apres
copie du correctif. E2 reste volontairement non lance jusqu'a E3 sain.
Le POST corrige a cree les tables ; MySQL strict a ensuite impose les quatre
colonnes texte sans valeur par defaut de `wp_posts`. Le seed les renseigne
desormais explicitement.

## Comment reprendre

1. `git fetch origin && git worktree add .worktrees/deployment-scripts -b feat/deployment-scripts origin/feat/deployment-scripts` (ou `git checkout feat/deployment-scripts` si pas de worktree existant).
2. Lire `deploiement/ARCHITECTURE.md` puis `deploiement/PLAN.md` (le plan en 9 taches, format checklist, prevu pour etre execute avec le skill `superpowers:subagent-driven-development`).
3. Reprendre a la Task 4 (chaine A E7-E8-E10). Les Tasks 1 a 3 sont fermees,
   revues et poussees : ne pas les redispatcher.
4. Continuer la methode implementeur, reviewer, correctifs, validation, push.

## Etat exact

- **Branche** : `feat/deployment-scripts`, remote `git@github.com:Robrtooo/maisonverte-attaque-defense.git` (le push HTTPS echoue sur cette machine faute de credential — utiliser SSH ou `gh auth login` si vous reprenez ailleurs).
- **Task 1 (socle commun)** : ferme, revu (1 tour de correctifs), pousse. Commits `88b412d..8be5bba`. Le premier tour de correctifs Task 3 ajoute une correction centrale de `mv_flag_value` pour normaliser les fins de ligne CRLF du CSV ; cette correction est validee par comparaison exacte des octets.
- **Task 2 (reseaux/TLS/offline/OPNsense)** : ferme, revu (1 tour de correctifs), pousse. Commits `8be5bba..6b7df9a`.
- **Task 3 (services DMZ E2-E5)** : **FERMEE, REVUE, 1 TOUR DE CORRECTIFS.**
  - Implementation initiale commitee dans `3d455ec` (`feat: add MaisonVerte DMZ services`).
  - Correctifs commites dans `ccd30da` (`fix: harden DMZ exploit paths and validation`).
  - E2 route E3, E4 et E5 sur l'unique bind TLS. Le Host non-DNS du PoC PHPMailer est route vers E3 par le SNI `shop.maisonverte.fr` tout en preservant le Host brut.
  - Le runbook et le flag E2 sont montes hors de `/home` : le chemin direct `/files/...` ne les atteint pas, tandis que le traversal intentionnel `/files../srv/...` reste exploitable.
  - E4 controle processus, configuration `/health` et contenu JSON representatif. E5 insere `readonly=false` dans le servlet `default` uniquement.
  - Relecture independante approuvee sans finding residuel. Suites locales vertes : foundation 66/66, infra 95/95, DMZ 134/134, `bash -n`, rendu de tous les Compose et `git diff --check`.
- **Task 4 (chaine A E7-E8-E10)** : prochaine tache, phase RED non commencee.
- **Tasks 5 a 9** : non commencees.

## Decision appliquee pour la Task 3

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
