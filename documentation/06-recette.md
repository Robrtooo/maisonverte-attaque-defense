# 06 - Recette

## Fiche d'execution

| Champ | Valeur |
|---|---|
| Date/heure | a renseigner |
| Operateur | a renseigner |
| Branche | `work/integration-deploy` |
| Commit teste | a renseigner |
| Profil(s) lance(s) | a renseigner |
| Etat final | a renseigner |

## Matrice de verification

| Controle | Resultat attendu | Observe | Preuve | Correction si echec |
|---|---|---|---|---|
| Git | branche `work/integration-deploy`, arbre propre hors artefacts attendus | a renseigner | `git status --branch` | a renseigner |
| Validation statique | `validate-static.sh` sans erreur | a renseigner | sortie commande | a renseigner |
| OPNsense WAN | `10.85.4.10` configure | a renseigner | capture | a renseigner |
| NAT 443 | `10.85.4.10:443 -> 192.168.10.50:443` | a renseigner | capture + test TCP/TLS | a renseigner |
| Images offline | toutes images requises presentes | a renseigner | `docker image ls` | a renseigner |
| Reseaux Docker | zones + micro-segments presents | a renseigner | `docker network ls/inspect` | a renseigner |
| Publication | seul E2 publie `192.168.10.50:443:443` | a renseigner | `docker ps` | a renseigner |
| Vhosts | `shop`, `api`, `vendeurs`, `cache` repondent en HTTPS | a renseigner | `curl -vk --resolve` | a renseigner |
| E4 sain | API accessible sans flag volontaire | a renseigner | curl + logs | a renseigner |
| E15 sain | Zabbix deploye en ADMIN, non expose WAN | a renseigner | `docker ps/inspect` | a renseigner |
| E16 sain | CRM deploye en SRV, sans flag volontaire | a renseigner | curl/logs internes | a renseigner |
| Chaine A | E2 -> E7 -> E8 -> E10 rejouable | a renseigner | commandes + alertes | a renseigner |
| Chaine B | E5 -> E14 -> E12 -> E11 rejouable | a renseigner | commandes + alertes | a renseigner |
| Chaine C | E3 -> E6 -> E9 -> E13 rejouable | a renseigner | commandes + alertes | a renseigner |
| Detection EveBox | alertes TP visibles pour etapes critiques | a renseigner | capture EveBox | a renseigner |
| Detection ELK | logs Docker indexes dans Kibana | a renseigner | capture Kibana | a renseigner |
| Persistance flags | flags encore presents apres relance controlee | a renseigner | relance + relecture masquee | a renseigner |
| Isolation N3 | aucun N3 accessible directement depuis DMZ/WAN | a renseigner | tests refuses | a renseigner |

## Commandes de preuve

```bash
git rev-parse HEAD
git status --branch --short
deploiement/90-orchestration/validate-static.sh
deploiement/00-infra/preflight.sh
deploiement/00-infra/verify-opnsense.sh
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker network ls
docker compose ls
```

Pour les vhosts publics :

```bash
curl -vk --resolve shop.maisonverte.fr:443:10.85.4.10 https://shop.maisonverte.fr/
curl -vk --resolve api.maisonverte.fr:443:10.85.4.10 https://api.maisonverte.fr/
curl -vk --resolve vendeurs.maisonverte.fr:443:10.85.4.10 https://vendeurs.maisonverte.fr/
curl -vk --resolve cache.maisonverte.fr:443:10.85.4.10 https://cache.maisonverte.fr/
```

## Regle de cloture

La recette est complete seulement quand chaque ligne de la matrice contient :

- resultat observe ;
- preuve exploitable ;
- correction ou justification si ecart ;
- absence de secret reutilisable hors lab dans la documentation finale.
