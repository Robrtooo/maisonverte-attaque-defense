# MaisonVerte Deployment Scripts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produire tous les scripts, fichiers Compose, configurations, seeds et validateurs necessaires au deploiement rejouable de MaisonVerte, sans executer le deploiement sur le lab avant la revue finale.

**Architecture:** Chaque service E2-E16 est un projet Compose independant attache a des reseaux Docker externes. Des micro-segments par chaine imposent les chemins A, B et C. E2 est l'unique terminaison TLS publique. ELK sain est isole d'E7. OPNsense et les VLAN restent manuels.

**Tech Stack:** Bash strict, Docker Compose v2+, images Vulhub epinglees, nginx, WordPress/MySQL, Tomcat, OFBiz, Elasticsearch, Redis, Samba, PostgreSQL, mongo-express/MongoDB, XXL-JOB/MySQL, Struts2, Jenkins, Zabbix, Elastic Stack, Suricata.

**Spec:** `deploiement/ARCHITECTURE.md`

## Global Constraints

- Ne lancer aucun script de deploiement, d'installation, d'import, de seed, de test d'exploit ou d'orchestration sur le lab pendant l'implementation.
- Les seules executions autorisees avant la revue finale sont les tests statiques, `bash -n`, `docker compose config`, les controles de texte et les tests unitaires utilisant des commandes simulees.
- Toute modification de script est commitee et poussee sur `origin/feat/deployment-scripts` apres validation de son lot.
- Aucun script destine au lab ne lance `docker pull`, `apt-get`, `apk add`, `yum`, `dnf`, `pip install`, `npm install`, `git clone` ou `suricata-update`.
- Aucun Compose n'utilise `latest`, `privileged`, `network_mode: host` ou `/var/run/docker.sock`.
- Tous les services utilisent `restart: unless-stopped`, une rotation de logs `10m x 3`, des healthchecks quand l'image fournit les outils necessaires, et `pull_policy: never`.
- Seul E2 publie un port hote : `192.168.10.50:443:443`. Kibana peut publier `127.0.0.1:5601:5601`. Aucun autre port n'est publie.
- E2, E3 et E5 sont les trois seuls N1. E4 reste sain. Les chaines A, B et C sont toutes livrees.
- Les valeurs de flags ne sont jamais dupliquees dans les scripts ou Compose ; elles sont lues depuis `enonce/flags-G04.csv` par identifiant.
- E7 vulnerable et l'Elasticsearch defensif ne partagent ni reseau, ni volume, ni secret, ni nom de cluster.
- Les VLAN, NAT, regles OPNsense et l'adresse WAN sont uniquement documentes et verifies, jamais modifies par les scripts.
- Les scripts doivent echouer clairement si une image, un fichier, une architecture amd64, une ressource ou une configuration requise manque.

---

### Task 1: Socle commun, inventaire et snapshot Vulhub

**Files:**
- Create: `deploiement/lib/common.sh`
- Create: `deploiement/config/lab.env.example`
- Create: `deploiement/config/networks.env`
- Create: `deploiement/config/services.env`
- Create: `deploiement/config/flags.map`
- Create: `deploiement/config/images.lock`
- Create: `deploiement/vendor/vulhub/UPSTREAM_COMMIT`
- Create: `deploiement/vendor/vulhub/<12 repertoires selectionnes>`
- Create: `deploiement/tests/static/test-foundation.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `mv_repo_root`, `mv_state_dir`, `mv_require_command`, `mv_require_file`, `mv_load_env`, `mv_flag_value`, `mv_compose`, `mv_wait_healthy`, `mv_log`, `mv_die`.
- Produces: constantes de reseaux, noms de projets, images et mapping `E2=1 ... E14=12` selon l'ordre N1 puis A/B/C documente.
- Consumes: `enonce/flags-G04.csv`, snapshot Vulhub au commit `aeaf65793f147f29bd50841ef77f4e9cad07ecc7`.

- [ ] **Step 1: Ecrire le test statique en echec**

Le test source `common.sh`, verifie les fonctions publiques, compte exactement 12 mappings de flags distincts, refuse une valeur absente et controle que les 12 chemins Vulhub sont presents avec le commit exact.

- [ ] **Step 2: Executer le test et confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-foundation.sh`

Expected: echec parce que `common.sh` et les fichiers de configuration n'existent pas.

- [ ] **Step 3: Implementer le socle minimal**

Utiliser `set -Eeuo pipefail`, chemins absolus derives du fichier courant, messages prefixes `[MaisonVerte]`, fichiers runtime sous `deploiement/state/` exclus de Git, lecture CSV exacte par `flag_id`, et commandes Compose avec `--project-name` stable. Copier mecaniquement les douze repertoires upstream depuis le clone local audite, sans leurs captures PNG, et conserver README/Compose/Dockerfile/configurations utiles.

- [ ] **Step 4: Valider sans deploiement**

Run: `bash -n deploiement/lib/common.sh deploiement/tests/static/test-foundation.sh`

Run: `bash deploiement/tests/static/test-foundation.sh`

Expected: tous les controles passent, aucune commande Docker mutante n'est executee.

- [ ] **Step 5: Commit et push**

```bash
git add .gitignore deploiement/lib deploiement/config deploiement/vendor deploiement/tests/static/test-foundation.sh
git commit -m "feat: add deployment foundation"
git push
```

### Task 2: Reseaux, TLS, offline et frontiere OPNsense

**Files:**
- Create: `deploiement/00-infra/preflight.sh`
- Create: `deploiement/00-infra/create-networks.sh`
- Create: `deploiement/00-infra/generate-tls.sh`
- Create: `deploiement/00-infra/import-offline-images.sh`
- Create: `deploiement/00-infra/print-opnsense-plan.sh`
- Create: `deploiement/00-infra/verify-opnsense.sh`
- Create: `deploiement/00-infra/prepare-runtime-secrets.sh`
- Create: `deploiement/90-orchestration/prepare-offline-bundle.sh`
- Create: `deploiement/tests/static/test-infra.sh`

**Interfaces:**
- Consumes: fonctions Task 1, `images.lock`, `networks.env`, `lab.env` optionnel.
- Produces: reseaux externes idempotents, certificats SAN `*.maisonverte.fr`, secrets runtime, bundle `maisonverte-images.tar` + `.sha256`, plan OPNsense lisible et controles read-only.

- [ ] **Step 1: Ecrire le test statique en echec**

Verifier l'absence de gestionnaires de paquets/telechargements dans les scripts lab, la liste exacte des six zones, des neuf micro-segments et des trois backends prives, le bind public unique, le checksum obligatoire avant `docker load`, les SAN publics et l'absence de commande de modification OPNsense.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-infra.sh`

- [ ] **Step 3: Implementer les scripts**

`preflight.sh` inspecte seulement Docker, Compose, amd64, RAM, disque, ports et images. `create-networks.sh` cree les reseaux avec labels et subnets fixes seulement s'ils sont absents. `generate-tls.sh` utilise `openssl` local et n'ecrase pas un certificat existant sans `--force`. `prepare-offline-bundle.sh` est marque `CONNECTED_HOST_ONLY=1`, refuse les adresses du lab et exporte les images deja presentes sur la machine connectee. `print-opnsense-plan.sh` imprime la NAT `10.85.4.10:443 -> 192.168.10.50:443`, les lignes hosts et le refus terminal journalise. `verify-opnsense.sh` ne fait que des tests TCP/TLS.

- [ ] **Step 4: Validation statique**

Run: `bash -n deploiement/00-infra/*.sh deploiement/90-orchestration/prepare-offline-bundle.sh deploiement/tests/static/test-infra.sh`

Run: `bash deploiement/tests/static/test-infra.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/00-infra deploiement/90-orchestration/prepare-offline-bundle.sh deploiement/tests/static/test-infra.sh
git commit -m "feat: add offline infrastructure tooling"
git push
```

### Task 3: Services DMZ E2-E5

**Files:**
- Create: `deploiement/10-dmz/install-e2-reverse-proxy.sh`
- Create: `deploiement/10-dmz/install-e3-wordpress.sh`
- Create: `deploiement/10-dmz/install-e4-mobile-api.sh`
- Create: `deploiement/10-dmz/install-e5-vendor-portal.sh`
- Create: `deploiement/10-dmz/services/e2/{compose.yaml,nginx.conf,conf.d/*.conf,content/*}`
- Create: `deploiement/10-dmz/services/e3/{compose.yaml,seed-wordpress.sh,content/*}`
- Create: `deploiement/10-dmz/services/e4/{compose.yaml,nginx.conf,html/*}`
- Create: `deploiement/10-dmz/services/e5/{compose.yaml,Dockerfile,content/*}`
- Create: `deploiement/tests/static/test-dmz.sh`

**Interfaces:**
- E2 publishes only `192.168.10.50:443:443`, routes four public hostnames and preserves `Host`, URI, method and request body.
- E2 joins `net-dmz` and `mv-a-edge`; E3 joins `net-dmz` and `mv-c-edge`; E5 joins `net-dmz` and `mv-b-edge`; E4 joins only `net-dmz`.
- E3 MySQL lives only on `mv-e3-db`.
- Each installer resolves its flag only when applicable, prepares exact mounts, calls its Compose project and runs an idempotent seed.

- [ ] **Step 1: Ecrire les tests en echec**

Verifier les quatre scripts unitaires, noms de conteneurs, reseaux, bind 443 unique, TLS, vhosts, preservation de `$http_host`, alias nginx vulnerable `/files`, absence de mise a jour WordPress, backend MySQL prive, Tomcat PUT writable et E4 sans endpoint dangereux.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-dmz.sh`

- [ ] **Step 3: Implementer E2-E5**

E2 conserve uniquement la variante traversal de Vulhub, stocke un runbook de recherche hors webroot et protege la route E7 par un jeton lu depuis ce runbook. E3 initialise WordPress 4.6 et des comptes/contenus MaisonVerte sans corriger PHPMailer. E4 expose des JSON catalogue/stocks/commandes/fidelite et un healthcheck sain. E5 derive l'image Tomcat 8.5.19, conserve `readonly=false`, ajoute un portail vendeur et un indice limite vers Jenkins. Aucun script ne lance les services pendant cette tache.

- [ ] **Step 4: Valider Bash et Compose sans lancer**

Run: `bash -n deploiement/10-dmz/*.sh deploiement/10-dmz/services/e3/seed-wordpress.sh deploiement/tests/static/test-dmz.sh`

Run: `find deploiement/10-dmz/services -name compose.yaml -exec docker compose -f {} config --quiet \;`

Run: `bash deploiement/tests/static/test-dmz.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/10-dmz deploiement/tests/static/test-dmz.sh
git commit -m "feat: add MaisonVerte DMZ services"
git push
```

### Task 4: Chaine A E7-E8-E10

**Files:**
- Create: `deploiement/20-srv/install-e7-product-search.sh`
- Create: `deploiement/20-srv/install-e8-session-cache.sh`
- Create: `deploiement/30-data/install-e10-catalog-orders.sh`
- Create: `deploiement/20-srv/services/e7/{compose.yaml,seed-search.sh}`
- Create: `deploiement/20-srv/services/e8/{compose.yaml,seed-cache.sh}`
- Create: `deploiement/30-data/services/e10/{compose.yaml,init/*.sql,seed-database.sh}`
- Create: `deploiement/tests/static/test-chain-a.sh`

**Interfaces:**
- E7 joins `mv-a-edge` + `mv-a-core`, exposes only 9200 et contient au moins 40 produits avant la recette CVE.
- E8 joins `mv-a-core` + `mv-a-data`, reste sans authentification pour le scenario et contient seulement le credential E10.
- E10 joins seulement `mv-a-data`, utilise un volume PGDATA, un compte administrateur unique pour `COPY PROGRAM`, et aucun port hote.

- [ ] **Step 1: Ecrire le test en echec**

Verifier images exactes, reseaux, absence 9300 publie, presence d'un document E7, absence `requirepass`, volume Redis, volume PostgreSQL, flag_id distinct et absence de port hote.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-chain-a.sh`

- [ ] **Step 3: Implementer la chaine A**

Les seeds sont idempotents et n'emploient que les clients deja inclus dans les images. Le secret E10 est ecrit dans une cle Redis dediee. Le reset Redis restaure les donnees apres un replay rogue-master sans modifier les autres chaines.

- [ ] **Step 4: Validation statique**

Run: `bash -n deploiement/20-srv/install-e{7,8}-*.sh deploiement/20-srv/services/e{7,8}/*.sh deploiement/30-data/install-e10-*.sh deploiement/30-data/services/e10/*.sh deploiement/tests/static/test-chain-a.sh`

Run: `find deploiement/20-srv/services/e7 deploiement/20-srv/services/e8 deploiement/30-data/services/e10 -name compose.yaml -exec docker compose -f {} config --quiet \;`

Run: `bash deploiement/tests/static/test-chain-a.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/20-srv deploiement/30-data deploiement/tests/static/test-chain-a.sh
git commit -m "feat: add exploitation chain A"
git push
```

### Task 5: Chaine B E14-E12-E11

**Files:**
- Create: `deploiement/20-srv/install-e14-jenkins.sh`
- Create: `deploiement/60-shops/install-e12-sales-consolidation.sh`
- Create: `deploiement/30-data/install-e11-client-database.sh`
- Create: `deploiement/20-srv/services/e14/{compose.yaml,init.groovy.d/*,content/*}`
- Create: `deploiement/60-shops/services/e12/{compose.yaml,seed-sales.sh,content/*}`
- Create: `deploiement/30-data/services/e11/{compose.yaml,seed-clients.sh}`
- Create: `deploiement/tests/static/test-chain-b.sh`

**Interfaces:**
- E14 joins `mv-b-edge` + `mv-b-core`, conserve Jenkins 2.441/CLI, retire `DEBUG=1`, JDWP 5005 et agent 50000.
- E12 frontend/executor rejoint `mv-b-core` + `mv-b-data`; MySQL reste sur `mv-e12-db`; seul l'executor 9999 est le maillon vulnerable.
- E11 web rejoint `mv-b-data`; MongoDB reste sur `mv-e11-db`; Basic Auth est configure avec un credential revele par E12.

- [ ] **Step 1: Ecrire le test en echec**

Verifier absence de `DEBUG`, 5005 et 50000, persistance Jenkins, fichier d'indice lisible par CLI, isolation des deux bases backend, maintien `/run` XXL et `/checkValid`, volumes et absence de ports hote.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-chain-b.sh`

- [ ] **Step 3: Implementer la chaine B**

Les images historiques ne sont pas reconstruites dans le lab. Les init Jenkins restent idempotents sur volume existant. Le premier contenu lisible du fichier Jenkins indique uniquement E12. Le job E12 revele uniquement le compte E11. MongoDB contient au moins 30 clients et un programme de fidelite.

- [ ] **Step 4: Validation statique**

Run: `bash -n deploiement/20-srv/install-e14-*.sh deploiement/60-shops/install-e12-*.sh deploiement/60-shops/services/e12/*.sh deploiement/30-data/install-e11-*.sh deploiement/30-data/services/e11/*.sh deploiement/tests/static/test-chain-b.sh`

Run: `find deploiement/20-srv/services/e14 deploiement/60-shops/services/e12 deploiement/30-data/services/e11 -name compose.yaml -exec docker compose -f {} config --quiet \;`

Run: `bash deploiement/tests/static/test-chain-b.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/20-srv deploiement/60-shops deploiement/30-data deploiement/tests/static/test-chain-b.sh
git commit -m "feat: add exploitation chain B"
git push
```

### Task 6: Chaine C E6-E9-E13

**Files:**
- Create: `deploiement/20-srv/install-e6-backoffice.sh`
- Create: `deploiement/20-srv/install-e9-marketing-files.sh`
- Create: `deploiement/60-shops/install-e13-wms.sh`
- Create: `deploiement/20-srv/services/e6/{compose.yaml,content/*}`
- Create: `deploiement/20-srv/services/e9/{compose.yaml,smb.conf,content/*}`
- Create: `deploiement/60-shops/services/e13/{compose.yaml,content/*}`
- Create: `deploiement/tests/static/test-chain-c.sh`

**Interfaces:**
- E6 joins `mv-c-edge` + `mv-c-core`, conserve OFBiz 18.12.10 et retire l'agent JDWP.
- E9 joins `mv-c-core` + `mv-c-spec`, expose seulement SMB 445 dans les reseaux Docker et conserve un partage guest writable au chemin `/home/share`.
- E13 rejoint seulement `mv-c-spec`, conserve Struts 2.3.30 et le parser multipart vulnerable.

- [ ] **Step 1: Ecrire le test en echec**

Verifier commande OFBiz sans JDWP, absence 5005, partage Samba writable et executable, absence 6699 publie, conservation du Content-Type OGNL, reseaux et flags distincts.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-chain-c.sh`

- [ ] **Step 3: Implementer la chaine C**

E6 contient uniquement l'indice vers E9. Le partage E9 contient exports comptables dates, visuels, campagnes et une procedure WMS ; le flag E9 reste hors du partage public. E13 est habille sans monter `/usr/src` ni `/root/.m2`. Aucun outil d'exploitation externe n'est telecharge par les scripts cible.

- [ ] **Step 4: Validation statique**

Run: `bash -n deploiement/20-srv/install-e{6,9}-*.sh deploiement/60-shops/install-e13-*.sh deploiement/tests/static/test-chain-c.sh`

Run: `find deploiement/20-srv/services/e6 deploiement/20-srv/services/e9 deploiement/60-shops/services/e13 -name compose.yaml -exec docker compose -f {} config --quiet \;`

Run: `bash deploiement/tests/static/test-chain-c.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/20-srv deploiement/60-shops deploiement/tests/static/test-chain-c.sh
git commit -m "feat: add exploitation chain C"
git push
```

### Task 7: Services sains, donnees et parcours fonctionnels

**Files:**
- Create: `deploiement/20-srv/install-e16-crm.sh`
- Create: `deploiement/50-admin/install-e15-zabbix.sh`
- Create: `deploiement/20-srv/services/e16/{compose.yaml,html/*}`
- Create: `deploiement/50-admin/services/e15/{compose.yaml,config/*}`
- Create: `deploiement/data/{products.json,orders.json,clients.json,tickets.csv,vendors.json,accounts.csv,exports/*}`
- Create: `deploiement/70-business/seed-all.sh`
- Create: `deploiement/70-business/demo-order-flow.sh`
- Create: `deploiement/70-business/demo-search.sh`
- Create: `deploiement/70-business/demo-nightly-sales.sh`
- Create: `deploiement/70-business/install-schedules.sh`
- Create: `deploiement/tests/static/test-business.sh`

**Interfaces:**
- E15 rejoint seulement `net-admin`; E16 rejoint seulement `net-srv`; aucun n'est vulnerable ou publie.
- Les donnees satisfont exactement les minima E-DAT-01 a E-DAT-07.
- Les demos produisent des IDs deterministes et des journaux horodates sans inventer de service vulnerable.

- [ ] **Step 1: Ecrire le test en echec**

Compter 40 produits, 60 commandes, 30 clients, 200 lignes de tickets, 8 vendeurs et tous les comptes imposes ; verifier les scripts E15/E16, leurs reseaux, leur absence de flags/CVE et les trois parcours R-03/R-05.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-business.sh`

- [ ] **Step 3: Implementer services, seeds et demos**

Les jeux de donnees sont fictifs, coherents et sans carte bancaire complete. Les scripts de demonstration ecrivent les memes references metier dans les applications concernees via leurs clients/API inclus, sans acces Internet et sans modifier les primitives vulnerables.

- [ ] **Step 4: Validation statique**

Run: `bash -n deploiement/20-srv/install-e16-*.sh deploiement/50-admin/install-e15-*.sh deploiement/70-business/*.sh deploiement/tests/static/test-business.sh`

Run: `find deploiement/20-srv/services/e16 deploiement/50-admin/services/e15 -name compose.yaml -exec docker compose -f {} config --quiet \;`

Run: `bash deploiement/tests/static/test-business.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/20-srv deploiement/50-admin deploiement/70-business deploiement/data deploiement/tests/static/test-business.sh
git commit -m "feat: add healthy services and business flows"
git push
```

### Task 8: ELK, Suricata et preuves de detection

**Files:**
- Create: `deploiement/50-admin/install-elk.sh`
- Create: `deploiement/50-admin/install-suricata-rules.sh`
- Create: `deploiement/50-admin/verify-detection.sh`
- Create: `deploiement/50-admin/services/elk/{compose.yaml,elasticsearch.yml,kibana.yml,logstash.conf,filebeat.yml,ilm-policy.json}`
- Create: `deploiement/50-admin/suricata/tp-local.rules`
- Create: `deploiement/50-admin/suricata/test-rules.sh`
- Create: `deploiement/tests/static/test-detection.sh`

**Interfaces:**
- ELK utilise uniquement `net-admin`, aucun volume/reseau E7, Kibana sur loopback, retention sept jours.
- Filebeat lit les journaux Docker en read-only sans socket ; Logstash accepte uniquement les sources locales configurees.
- Les SID locaux sont uniques et commencent a `9000001`.
- L'installation Suricata cible la sonde via SSH ou un chemin local explicite, sauvegarde le fichier precedent et execute `suricata -T` avant rechargement.

- [ ] **Step 1: Ecrire le test en echec**

Verifier quatre images Elastic de meme version, isolement E7, montages read-only, absence docker.sock/privileged, bind Kibana loopback, ILM sept jours, SID uniques, couverture SNI N1/recon/canaries et rollback Suricata.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-detection.sh`

- [ ] **Step 3: Implementer ELK et Suricata**

Les secrets Elastic sont generes hors Git. Le mode degrade preserve `docker compose logs` et EveBox mais retourne un statut explicite. Les regles Suricata ne pretendent pas voir les bridges intra-hote ; les detecteurs lateraux correspondants sont des recherches/logs ELK documentes.

- [ ] **Step 4: Validation statique**

Run: `bash -n deploiement/50-admin/*.sh deploiement/50-admin/suricata/*.sh deploiement/tests/static/test-detection.sh`

Run: `docker compose -f deploiement/50-admin/services/elk/compose.yaml config --quiet`

Run: `bash deploiement/tests/static/test-detection.sh`

- [ ] **Step 5: Commit et push**

```bash
git add deploiement/50-admin deploiement/tests/static/test-detection.sh
git commit -m "feat: add ELK and Suricata detection"
git push
```

### Task 9: Orchestration, recette et documentation d'exploitation

**Files:**
- Create: `deploiement/90-orchestration/deploy-all.sh`
- Create: `deploiement/90-orchestration/deploy-parallel.sh`
- Create: `deploiement/90-orchestration/stop-all.sh`
- Create: `deploiement/90-orchestration/reset-exploit-artifacts.sh`
- Create: `deploiement/90-orchestration/verify-all.sh`
- Create: `deploiement/80-validation/verify-services.sh`
- Create: `deploiement/80-validation/verify-network-matrix.sh`
- Create: `deploiement/80-validation/verify-flags.sh`
- Create: `deploiement/80-validation/verify-business.sh`
- Create: `deploiement/80-validation/verify-restart.sh`
- Create: `deploiement/80-validation/replay-chain-a.sh`
- Create: `deploiement/80-validation/replay-chain-b.sh`
- Create: `deploiement/80-validation/replay-chain-c.sh`
- Create: `deploiement/tests/static/test-global.sh`
- Modify: `deploiement/README.md`
- Modify: `README.md`
- Modify: `suivi/CHECKLIST.md`
- Modify: `suivi/SUIVI.md`

**Interfaces:**
- `deploy-all.sh` execute preflight, secrets, TLS, reseaux, services par vagues de dependances, seeds, ELK puis verifications non destructives.
- `deploy-parallel.sh` parallellise seulement les services independants et collecte tous les codes retour.
- `verify-all.sh` orchestre les preuves sans masquer un echec.
- Les replays de chaine sont separes du deploiement et ne sont jamais appeles automatiquement.

- [ ] **Step 1: Ecrire le test global en echec**

Verifier qu'il existe exactement un installateur E2-E16, que tous sont references par l'orchestrateur, que l'ordre respecte les dependances, que les replays ne sont pas appeles, que les validations couvrent I/S/Q/V/C/D/P/F et que tous les scripts sont syntaxiquement valides.

- [ ] **Step 2: Confirmer l'echec attendu**

Run: `bash deploiement/tests/static/test-global.sh`

- [ ] **Step 3: Implementer orchestration et validateurs**

Utiliser des groupes de jobs explicites, `wait` avec collecte de statut, traps propres et resume idempotent. `verify-restart.sh` demande une confirmation interactive avant `down`, attend au maximum dix minutes et produit un dossier horodate sous `state/evidence/`. Les replays indiquent les commandes et preuves mais exigent `--confirm-authorized-lab`.

- [ ] **Step 4: Mettre a jour les documents courts**

Remplacer la mention "chaine C si temps", documenter l'unique 443, les micro-segments, la limite de visibilite Suricata, ELK separe, les commandes d'orchestration et la regle "tout script modifie est pousse". Ne pas transformer les documents de suivi en rapport final.

- [ ] **Step 5: Validation statique complete**

Run: `find deploiement -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n`

Run: `find deploiement -type f -name 'compose.yaml' -exec docker compose -f {} config --quiet \;`

Run: `for test in deploiement/tests/static/test-*.sh; do bash "$test"; done`

Run: `git diff --check origin/main...HEAD`

Expected: zero echec, zero lancement de conteneur et zero connexion au lab.

- [ ] **Step 6: Commit et push**

```bash
git add README.md suivi deploiement
git commit -m "feat: complete deployment orchestration"
git push
```

## Final Review Gate

Apres les neuf taches, generer un package de diff depuis `origin/main` et
realiser une revue globale avec le modele le plus capable. Une seule vague de
correction est autorisee, suivie d'une re-revue ciblee. Reexecuter ensuite
toutes les validations statiques et pousser chaque correction.

Ne pas merger dans `main` et ne lancer aucun script sur le lab pendant cette
phase. La premiere execution fera l'objet d'une etape distincte apres remise
du rapport de revue a l'utilisateur.
