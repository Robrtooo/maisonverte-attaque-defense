# 03 - Deploiement

## Precondition

- Brancher la recette sur `work/integration-deploy`.
- Importer les images offline listees dans `deploiement/config/images.lock`.
- Verifier que les scripts de lab ne telechargent rien.
- Configurer OPNsense manuellement : WAN/LAN, VLAN, routage, NAT TCP 443 vers `192.168.10.50:443`.
- Verifier `vulndb` : amd64, RAM, disque, Docker Compose, ports, fichiers de configuration.

Commandes de reference :

```bash
git status --branch
deploiement/00-infra/preflight.sh
deploiement/00-infra/verify-opnsense.sh
deploiement/90-orchestration/validate-static.sh
```

## Ordre conseille

Profil minimal :

```bash
deploiement/90-orchestration/deploy-maisonverte.sh poc
```

Puis une seule chaine a la fois selon recette :

```bash
deploiement/90-orchestration/deploy-maisonverte.sh chain-a
deploiement/90-orchestration/deploy-maisonverte.sh chain-b
deploiement/90-orchestration/deploy-maisonverte.sh chain-c
```

Detection apres import des images ELK :

```bash
deploiement/90-orchestration/deploy-profile.sh detection
```

`full-risky` existe mais ne doit pas etre lance en premier : `vulndb` mesure
environ 7.95 Gio RAM et les JVM/ELK peuvent saturer le lab.

## Profils utiles

| Profil | Role |
|---|---|
| `foundation` | socle, reseaux, secrets runtime |
| `dmz` | E2, E3, E4, E5 |
| `business` | donnees et workflows metier |
| `detection` | ELK defensif et notes Suricata |
| `chain-a` | E7, E8, E10 |
| `chain-b` | E14, E12, E11 |
| `chain-c` | E6, E9, E13 |
| `stop-heavy` | arret services lourds pour economiser la RAM |

## Points de controle apres lancement

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker network ls
docker compose ls
```

A consigner :

- date, operateur, branche et commit ;
- profil lance et sortie courte ;
- services `healthy` ou delai JVM observe ;
- ports publies ;
- erreurs et corrections appliquees.

## Preuves a ajouter

- Sortie `preflight.sh`.
- Capture NAT/rules OPNsense.
- Capture `docker ps` montrant E2 en `192.168.10.50:443:443`.
- Capture des quatre vhosts publics en HTTPS.
- Healthchecks des profils lances.
- Logs d'import images offline si l'import est refait.
