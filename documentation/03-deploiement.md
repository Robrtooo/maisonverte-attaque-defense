# 03 · Déploiement

*Ce document décrit les préconditions, l'ordre de lancement recommandé et les points de contrôle à effectuer après chaque déploiement.*

---

## Préconditions

Avant tout déploiement, se brancher sur `work/integration-deploy`, importer les images hors ligne listées dans `deploiement/config/images.lock`, et vérifier qu'aucun script de lab ne télécharge quoi que ce soit. OPNsense doit être configuré à la main — WAN/LAN, VLAN, routage, NAT TCP 443 vers `192.168.10.50:443` — et `vulndb` vérifié sur son architecture amd64, sa RAM, son disque, Docker Compose, ses ports et ses fichiers de configuration.

Commandes de référence :

```bash
git status --branch
deploiement/00-infra/preflight.sh
deploiement/00-infra/verify-opnsense.sh
deploiement/90-orchestration/validate-static.sh
```

## Ordre conseillé

Profil minimal :

```bash
deploiement/90-orchestration/deploy-maisonverte.sh poc
```

Puis une seule chaîne à la fois, selon la recette :

```bash
deploiement/90-orchestration/deploy-maisonverte.sh chain-a
deploiement/90-orchestration/deploy-maisonverte.sh chain-b
deploiement/90-orchestration/deploy-maisonverte.sh chain-c
```

Détection, après import des images ELK :

```bash
deploiement/90-orchestration/deploy-profile.sh detection
```

> **Attention** — le profil `full-risky` existe mais ne doit pas être lancé en premier : `vulndb` mesure environ 7,95 Gio de RAM et les JVM/ELK peuvent saturer le lab.

## Profils disponibles

| Profil | Rôle |
|---|---|
| `foundation` | socle, réseaux, secrets runtime |
| `dmz` | E2, E3, E4, E5 |
| `business` | données et workflows métier |
| `detection` | ELK défensif et notes Suricata |
| `chain-a` | E7, E8, E10 |
| `chain-b` | E14, E12, E11 |
| `chain-c` | E6, E9, E13 |
| `stop-heavy` | arrêt des services lourds pour économiser la RAM |

## Points de contrôle après lancement

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker network ls
docker compose ls
```

À consigner systématiquement : la date, l'opérateur, la branche et le commit, le profil lancé et sa sortie courte, l'état `healthy` des services ou le délai JVM observé, les ports publiés, ainsi que les erreurs rencontrées et les corrections apportées.

## Preuves à ajouter

Les preuves à ajouter couvrent la sortie de `preflight.sh`, une capture du NAT et des règles OPNsense, un `docker ps` montrant E2 sur `192.168.10.50:443:443`, une capture des quatre vhosts publics en HTTPS, les healthchecks des profils lancés, et les logs d'import des images hors ligne si l'import est rejoué.

---

**Navigation** : ← [`02-architecture.md`](02-architecture.md) · Suivant → [`04-exploitation.md`](04-exploitation.md)
