# MaisonVerte - contexte de reprise

## Git

- Branche : `work/integration-deploy`.
- Remote : `origin/work/integration-deploy`.
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

## Reste a faire

1. Finaliser OPNsense manuellement : WAN `10.85.4.10`, LAN `192.168.10.1`, VLAN/routage, NAT TCP 443, regles minimales.
2. Poser/valider regles Suricata sur NSM puis controler EveBox `http://192.168.10.30:5636`.
3. Executer chemins d'exploitation et confirmer 12 flags sans corriger vulnerabilites intentionnelles.
4. Completer drafts `documentation/` avec captures et resultat de `check-all-services.sh`.
5. Prevoir tunnel SSH vers Kibana, lie a `127.0.0.1:5601` sur `vulndb`.

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
- Acces local verifie le 2026-09-16 : WireGuard `conf_lab` actif; tunnel SSH actif; EveBox `127.0.0.1:5636`, OPNsense `127.0.0.1:8443` et registre `127.0.0.1:5001` repondent HTTP `200`.
- Orchestrateur : `deploiement/90-orchestration/deploy-maisonverte.sh`.
- Verification : `deploiement/90-orchestration/check-all-services.sh` (`--list` pour endpoints seuls).
