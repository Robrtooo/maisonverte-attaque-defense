# 00 · Structure et preuves à collecter

*Ce document cadre la documentation technique du projet : comment elle s'organise, comment la rédiger, et quelles preuves sont attendues avant de considérer une étape close.*

---

## Structure de la documentation

| # | Document | Contenu |
|---|---|---|
| 01 | [`01-cadrage.md`](01-cadrage.md) | Objectif, périmètre, contraintes et limites du TP |
| 02 | [`02-architecture.md`](02-architecture.md) | Topologie du lab, publication, réseaux Docker, services et chaînes |
| 03 | [`03-deploiement.md`](03-deploiement.md) | Préconditions, ordre de lancement, profils, contrôles après démarrage |
| 04 | [`04-exploitation.md`](04-exploitation.md) | Chaînes A, B et C : préconditions, pivots, résultats attendus |
| 05 | [`05-detection.md`](05-detection.md) | Sources réseau et logs, Suricata/EveBox, ELK, SID et requêtes |
| 06 | [`06-recette.md`](06-recette.md) | Matrice de vérification, résultat attendu, résultat observé, preuve |
| 07 | [`07-endpoints-et-verification.md`](07-endpoints-et-verification.md) | Inventaire des endpoints publics, défense et internes, script de vérification globale |

## Règles de rédaction

La documentation reste factuelle : elle distingue ce qui est scripté, ce qui est déployé, ce qui est vérifié statiquement et ce qui est vérifié en lab — quatre états à ne jamais confondre dans une même phrase. Aucun secret ni aucun flag n'y est dupliqué ; on y référence `deploiement/config/flags.map` et `enonce/flags-G04.csv` plutôt que d'en recopier la valeur. L'exclusivité d'une image Vulhub n'est jamais affirmée : seules les failles intentionnelles et recettées y sont documentées, pas tout ce qu'une image pourrait par ailleurs exposer. Les limites de visibilité sont notées explicitement — Suricata voit le trafic qui traverse le pont L2, pas nécessairement les flux intra-hôte entre bridges Docker. Enfin, les preuves de terrain ne sont ajoutées qu'après exécution réelle de l'étape, avec date, opérateur, profil lancé et commit testé.

## Preuves obligatoires

| Sujet | Preuve à ajouter | Source attendue |
|---|---|---|
| Branche et version | Commit testé, branche `work/integration-deploy`, date/heure | `git rev-parse HEAD`, `git status --branch` |
| OPNsense | WAN `10.85.4.10`, LAN, VLAN 10/11, NAT TCP 443 vers `192.168.10.50:443` | captures OPNsense + `verify-opnsense.sh` |
| Hôte Docker | RAM, disque, architecture amd64, Docker/Compose, ports libres | sortie `preflight.sh` |
| Images offline | images présentes et importées sans pull Internet | `images.lock`, `docker image ls`, logs `import-offline-images.sh` |
| Réseaux Docker | six zones + micro-segments A/B/C créés | `docker network ls`, `docker network inspect` |
| TLS / publication | seul bind public `192.168.10.50:443:443`, vhosts publics | `docker ps`, `curl -vk --resolve ...` |
| Profils | `poc`, puis une chaîne `chain-a`, `chain-b` ou `chain-c` | logs `deploy-maisonverte.sh` |
| Healthchecks | statut des conteneurs du profil lancé | `docker compose ps`, logs service si échec |
| Données métier | catalogue, commandes, clients, tickets, exports | scripts démo R-03/R-04/R-05 |
| Chaîne A | `E2 → E7 → E8 → E10`, flag final | commandes, captures, logs Suricata/ELK |
| Chaîne B | `E5 → E14 → E12 → E11`, flag final | commandes, captures, logs Suricata/ELK |
| Chaîne C | `E3 → E6 → E9 → E13`, flag final | commandes, captures, logs Suricata/ELK |
| Services sains | E4, E15, E16 accessibles selon leur rôle et sans flag volontaire | healthchecks + tests fonctionnels |
| Détection Suricata | SID locaux `9000001+`, alertes EveBox | capture EveBox + `eve.json` |
| Détection ELK | ingestion logs Docker, recherches Kibana | capture Kibana + requêtes |
| Persistance | flags et volumes présents après `down`/`up -d` ou redémarrage contrôlé | commandes de relance + relecture des flags |
| Isolation | aucun N3 direct depuis la DMZ, aucun port backend publié | `docker ps`, `docker inspect`, tests d'accès refusés |

## Captures conseillées

Les captures conseillées couvrent le schéma réseau final issu de `suivi/schema-maisonverte.drawio`, les pages publiques `shop.maisonverte.fr`, `api.maisonverte.fr`, `vendeurs.maisonverte.fr` et `cache.maisonverte.fr`, une alerte EveBox par étape critique, les logs Kibana corrélant l'étape attaquant, et un terminal montrant le profil lancé, les conteneurs à l'état `healthy`, puis le flag masqué partiellement.

## Statut actuel

La documentation n'existe encore qu'en brouillon à la racine du dépôt (`01-cadrage.md` à `06-recette.md`), et `deploiement/PROGRESS.md` indique les tâches 1 à 9 comme scriptées ou intégrées. Sur le terrain, la DMZ est indiquée comme déjà déployée sur `vulndb` au commit `a5d6611` ; les autres preuves restent à ajouter après exécution de la recette.

---

**Navigation** : [`README.md`](README.md) · Suivant → [`01-cadrage.md`](01-cadrage.md)
