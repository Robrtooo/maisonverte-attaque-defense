# MaisonVerte - contexte de reprise

## Git

- Branche principale et branche GitHub par defaut : `main`.
- `main` inclut `feat/deployment-scripts`, `work/current-task5`, `work/current-task6`, `work/current-task7` et `work/integration-deploy`.
- `main` et `work/integration-deploy` sont synchronisees avant reprise de la chaine A.
- Toute modification de script doit etre committee et poussee.
- Documentation de travail : `documentation/` (drafts courts deja pousses).
- Inventaire endpoints : `documentation/07-endpoints-et-verification.md`.
- Controle global : `deploiement/90-orchestration/check-all-services.sh`.

## Etat au 2026-09-16

- DMZ E2-E5 : deployee et saine.
- Chaine A E7/E8/E10 : deployee et saine.
- Chaine B E14/E12/E11 : deployee et saine.
- Chaine C E6/E9/E13 : deployee et saine.
- Services sains E15/E16 : deployes et sains.
- ELK : Elasticsearch, Kibana et Filebeat deployes et sains.
- Filebeat collecte les logs Docker dans `maisonverte-docker-*`.
- 26 conteneurs actifs, aucun conteneur arrete.
- RAM lab : 7.95 Gio total, environ 3.5 Gio disponible apres deploiement complet.
- Donnees validees : E7 `41` documents, E10 `40` produits / `60` commandes, E11 `30` clients, E12 `200` lignes de ticket.

## Correctifs integration pousses

- Preflight adapte aux profils et controle de port limite a la DMZ.
- Flag Jenkins monte hors du contenu Vulhub.
- E15 utilise MariaDB + Zabbix server/web `7.0.27`, car image appliance retiree.
- Elasticsearch defensif utilise un volume Docker inscriptible.
- E16 monte donnees dans `/srv/maisonverte-data`, hors webroot en lecture seule.
- Healthcheck et verification Filebeat utilisent `--strict.perms=false`.

## Verification executee

- Tests statiques business : `72` checks, `0` echec.
- Tests statiques detection : `0` echec.
- Compose E16 et ELK valides.
- E16 sert `/data/clients.json` et passe son healthcheck.
- Filebeat passe son healthcheck et `verify-detection.sh`.
- Indices ELK alimentes jusqu'a `maisonverte-docker-2026.09.16`.
- Controle global execute sur `vulndb` : `43 OK, 0 FAIL`.
- 24 conteneurs MaisonVerte sains, 4 vhosts TLS internes/WAN, EveBox, Kibana, donnees metier et ingestion ELK verifies.

## Session terrain du 2026-09-16 (post-acces reel)

- Acces reel confirme sur les 4 machines lab (poste, OPNsense, nsm, vulndb) via tunnel SSH fourni.
- Suricata live sur `nsm` a 29 SID actifs (6 baseline + 19 G04 + **4 nouvelles regles SNI/TLS 9000026-9000029**, ajoutees en direct sur la sonde pour detecter le SNI `E2/E3/E5/E4` faute de contenu HTTP visible en TLS 1.3). **Ces 4 regles ne sont pas encore reportees** dans `deploiement/80-detection/tp-local.rules` ni dans `documentation/08-regles-suricata.md` : a synchroniser avant rendu.
- `fast.log` confirme : seules les regles de reconnaissance/SNI ont declenche a ce stade, aucune regle d'exploitation/pivot/isolation — les 3 chaines n'ont pas encore ete rejouees pour de vrai.
- E2 (`cache.maisonverte.fr`) : traversal `/files../` confirme exploitable en conditions WAN reelles (lecture de `runbook.txt` via l'alias `/files -> /home`). Meme requete sur `flag.txt` renvoie 403 (proprietaire du fichier monte != UID nginx, a investiguer si utilise comme preuve de flag).
- E6 OFBiz (`backoffice-srv01`) : le compte `admin` utilisait encore le mot de passe demo par defaut `ofbiz` (jamais rotate). RCE Groovy confirme via `/webtools/control/ProgramExport` (delegator entity-engine accessible).
  - Cause d'un blocage/hang recurrent identifiee : `HashCrypt.cryptUTF8(...)` declenche `SecureRandom` qui bloque sur l'entropie du conteneur (JVM 8 + `/dev/random`). **Correctif applique** : ajout de `-Djava.security.egd=file:/dev/./urandom` a `JAVA_TOOL_OPTIONS` dans `deploiement/20-srv/services/e6/compose.yaml` (commite ici + applique en direct sur `vulndb`, conteneur recree avec le meme volume `mv-e6_e6-ofbiz-runtime`, healthcheck OK).
  - Rotation effective du mot de passe `admin` : **en cours, non confirmee au moment de cette note** (nouveau secret genere via `prepare-runtime-secrets.sh e6-admin-password 18`, stocke sous `deploiement/state/secrets/e6-admin-password` sur `vulndb`). A reverifier (login avec l'ancien mdp doit echouer, login avec le nouveau doit reussir) avant de considerer le correctif clos.
- Comptes CDC (§11 Annexe, `deploiement/data/accounts.csv`) : confirme qu'aucun des 21 comptes nominatifs n'existe reellement dans un systeme d'auth — seulement la CSV statique, importee sans transformation en comptes reels (`E-SEC-05` non satisfait). Perimetre retenu pour creation reelle : **OFBiz (13 comptes : `f.leclerc` + `resp.mag001`-`012`)** et **WordPress E3 (3 comptes : `agence.web`, `n.roussel`, `client_test`)** ; les autres services restent annuaire-seul (a justifier en doc, pas de modele d'auth par utilisateur reel).

## Reste a faire

1. Finaliser OPNsense manuellement : WAN `10.85.4.10`, LAN `192.168.10.1`, VLAN/routage, NAT TCP 443, regles minimales.
2. Reporter les 4 regles Suricata live (SID 9000026-9000029, SNI TLS) dans `deploiement/80-detection/tp-local.rules` et `documentation/08-regles-suricata.md`.
3. Confirmer la rotation du mot de passe admin OFBiz (E6) puis creer les 13 comptes OFBiz + 3 comptes WordPress (E3) valides avec l'equipe, idealement via un script rejouable (`install-eX-*.sh`).
4. Executer chemins d'exploitation (l'equipe rejoue elle-meme les 3 chaines) et confirmer 12 flags sans corriger vulnerabilites intentionnelles.
5. Completer drafts `documentation/` (04-exploitation, 06-recette, 07-endpoints) avec captures et resultats reels une fois les chaines rejouees.
6. Prevoir tunnel SSH vers Kibana, lie a `127.0.0.1:5601` sur `vulndb`.

## Contraintes

- Lab sans Internet : aucun `docker pull`, `apt-get` ou `suricata-update`.
- 12 vulnerabilites intentionnelles, a conserver exploitables pendant POC.
- Images Vulhub peuvent contenir faiblesses heritees : ne pas promettre une seule faille par service.
- Pont Suricata fourni par plateforme; configuration finale manuelle.
- Si preflight bloque sur disque, utiliser temporairement `MV_PREFLIGHT_MIN_DISK_MB=15360` (environ 20 Gio libres observes).

## Acces lab

- Exposition : `10.85.4.0/24`; firewall WAN `10.85.4.10`; poste `10.85.4.20`.
- Interne : `192.168.10.0/24`; firewall LAN `192.168.10.1`; `vulndb` `192.168.10.50`.
- NSM/EveBox : `192.168.10.30:5636`.
- Acces local verifie le 2026-09-16 : WireGuard `conf_lab` actif; tunnel SSH actif; EveBox `http://127.0.0.1:5636/`, OPNsense `https://127.0.0.1:8443/` et registre `http://127.0.0.1:5001/` repondent HTTP `200`. Interface EveBox ouverte avec 7 alertes visibles.
- Blocage acces moteur Suricata : nouveau SSH vers `etudiant@10.85.4.20` refuse le mot de passe historique `Defense2600!`; tunnel EveBox existant reste actif. Confirmer credentials du poste avant `ssh_nsm`.
- Orchestrateur : `deploiement/90-orchestration/deploy-maisonverte.sh`.
- Verification : `deploiement/90-orchestration/check-all-services.sh` (`--list` pour endpoints seuls).
