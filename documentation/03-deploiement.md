# 03 - Deploiement

- Precondition : images Docker chargees offline ; aucun `docker pull`.
- OPNsense manuel : WAN/LAN, VLAN, routage, NAT TCP 443 vers `192.168.10.50:443`.
- Base : `deploiement/90-orchestration/deploy-maisonverte.sh poc`.
- Ajouter une seule chaine : `chain-a`, `chain-b` ou `chain-c`.
- ELK apres import images : mode `detection`.
- Ne pas lancer `full-risky` en premier.
- Ajouter : horodatage, operateur, sortie preflight, containers/healthchecks.

