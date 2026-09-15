# Deploiement

Ce dossier recevra les scripts de deploiement versionnes.

Convention retenue :

- un script par service ;
- un nom explicite avec la reference du service ;
- un script relancable autant que possible ;
- pas de dependance Internet pendant l'execution dans le lab ;
- les scripts d'orchestration ne remplacent pas les scripts unitaires, ils les appellent.

Exemples de noms attendus :

- `10-dmz/install-e2-reverse-proxy.sh`
- `10-dmz/install-e3-wordpress.sh`
- `10-dmz/install-e5-portail-vendeurs.sh`
- `20-srv/install-e7-recherche-produits.sh`
- `50-admin/install-suricata-rules.sh`
- `90-orchestration/deploy-chain-a.sh`
