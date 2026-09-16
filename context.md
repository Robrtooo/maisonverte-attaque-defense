# MaisonVerte - contexte de reprise

## Etat git

- Branche integree : `work/integration-deploy`
- Commit : `361f94d feat: add detection and orchestration scripts`
- Remote : `origin/work/integration-deploy`
- Base historique : `origin/feat/deployment-scripts`
- Worktrees source deja pousses : `work/current-task5`, `work/current-task6`, `work/current-task7`.

## Ce qui existe

- DMZ E2-E5 deja deployee sur `vulndb` : commit `a5d6611`.
- Chaine A : E7, E8, E10.
- Chaine B : E14, E12, E11.
- Chaine C : E6, E9, E13.
- Services sains : E4, E15, E16.
- Detection : stack ELK, notes/verification Suricata.
- Orchestration : `deploiement/90-orchestration/deploy-maisonverte.sh`.

## Regles importantes

- 12 vuln intentionnelles. Images Vulhub peuvent contenir autres faiblesses heritees : ne jamais promettre "une seule vuln par service".
- Lancer `poc`, puis une seule chaine (`chain-a`, `chain-b` ou `chain-c`). Ne pas lancer `full-risky` au premier passage : RAM cible ~7.95 Gio.
- Aucun Internet lab : aucune installation/pull/update en ligne.
- Toute modification de script doit etre committee et poussee vers GitHub.

## Avant deploiement

1. Terminer review integration non terminee : commande interrompue par utilisateur avant resultat.
2. Sur `vulndb`, lancer `deploiement/00-infra/preflight.sh` : verifier images offline, surtout ELK 7.17.24.
3. Configurer OPNsense manuellement : WAN `10.85.4.10`, LAN `192.168.10.1`, VLAN/routage, NAT TCP 443 vers `192.168.10.50:443`, regles minimales.
4. Deployer : `deploiement/90-orchestration/deploy-maisonverte.sh poc`.
5. Ajouter une chaine, tester chemin/flag, puis valider Suricata/EveBox et ELK.

## Topologie lab

- Exposition : `10.85.4.0/24`; firewall WAN `10.85.4.10`; poste `10.85.4.20`.
- Interne nord/sud : `192.168.10.0/24`, VLAN 10/11, pont Suricata transparent.
- NSM admin/EveBox : `192.168.10.30:5636`.
- `vulndb` : `192.168.10.50`.
