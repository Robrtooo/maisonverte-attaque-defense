# 00 - Structure et preuves a collecter

## Structure proposee

1. `01-cadrage.md` : objectif, perimetre, contraintes, roles et limites du TP.
2. `02-architecture.md` : topologie lab, publication, reseaux Docker, services et chaines.
3. `03-deploiement.md` : preconditions, ordre de lancement, profils, controles apres demarrage.
4. `04-exploitation.md` : chemins A, B et C, preconditions, pivots, resultats attendus.
5. `05-detection.md` : sources reseau et logs, Suricata/EveBox, ELK, SID et requetes.
6. `06-recette.md` : matrice de verification, resultat attendu, resultat observe, preuve.

## Regles de redaction

- Rester factuel : distinguer ce qui est scripte, deployee, verifie statiquement et verifie en lab.
- Ne pas dupliquer de secrets ni de flags ; referencer `config/flags.map` et `enonce/flags-G04.csv`.
- Ne pas affirmer l'exclusivite d'une image Vulhub. Documenter seulement les failles intentionnelles et recettees.
- Noter les limites de visibilite : Suricata voit le trafic qui traverse le pont L2, pas forcement les flux intra-hote Docker.
- Ajouter les preuves terrain apres execution, avec date, operateur, profil lance et commit teste.

## Preuves obligatoires

| Sujet | Preuve a ajouter | Source attendue |
|---|---|---|
| Branche et version | Commit teste, branche `work/integration-deploy`, date/heure | `git rev-parse HEAD`, `git status --branch` |
| OPNsense | WAN `10.85.4.10`, LAN, VLAN 10/11, NAT TCP 443 vers `192.168.10.50:443` | captures OPNsense + `verify-opnsense.sh` |
| Hote Docker | RAM, disque, architecture amd64, Docker/Compose, ports libres | sortie `preflight.sh` |
| Images offline | images presentes et importees sans pull Internet | `images.lock`, `docker image ls`, logs `import-offline-images.sh` |
| Reseaux Docker | six zones + micro-segments A/B/C crees | `docker network ls`, `docker network inspect` |
| TLS/publication | seul bind public `192.168.10.50:443:443`, vhosts publics | `docker ps`, `curl -vk --resolve ...` |
| Profils | `poc`, puis une chaine `chain-a`, `chain-b` ou `chain-c` | logs `deploy-maisonverte.sh` |
| Healthchecks | statut des conteneurs du profil lance | `docker compose ps`, logs service si echec |
| Donnees metier | catalogue, commandes, clients, tickets, exports | scripts demo R-03/R-04/R-05 |
| Chaine A | E2 -> E7 -> E8 -> E10, flag final | commandes, captures, logs Suricata/ELK |
| Chaine B | E5 -> E14 -> E12 -> E11, flag final | commandes, captures, logs Suricata/ELK |
| Chaine C | E3 -> E6 -> E9 -> E13, flag final | commandes, captures, logs Suricata/ELK |
| Services sains | E4, E15, E16 accessibles selon role et sans flag volontaire | healthchecks + tests fonctionnels |
| Detection Suricata | SID locaux `9000001+`, alertes EveBox | capture EveBox + `eve.json` |
| Detection ELK | ingestion logs Docker, recherches Kibana | capture Kibana + requetes |
| Persistance | flags et volumes apres `down`/`up -d` ou redemarrage controle | commandes de relance + relecture flags |
| Isolation | aucun N3 direct depuis DMZ, pas de port backend publie | `docker ps`, `docker inspect`, tests d'acces refuses |

## Captures conseillees

- Schema reseau final depuis `suivi/schema-maisonverte.drawio`.
- Page publique `shop.maisonverte.fr`, `api.maisonverte.fr`, `vendeurs.maisonverte.fr`, `cache.maisonverte.fr`.
- EveBox avec une alerte par etape critique.
- Kibana avec logs applicatifs correlant l'etape attaquant.
- Terminal avec profil lance, conteneurs `healthy`, puis flag masque partiellement.

## Statut actuel

- Documentation : brouillons initialises dans `documentation/`.
- Scripts : tasks 1 a 9 indiquees comme scriptees dans `deploiement/PROGRESS.md`.
- Lab : DMZ indiquee comme deja deployee au commit `a5d6611`; autres preuves terrain restent a ajouter apres recette.
