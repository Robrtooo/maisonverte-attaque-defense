# 06 · Recette

*Ce document est la matrice de vérification finale. La recette n'est considérée close que lorsque chaque ligne est renseignée avec un résultat observé et une preuve.*

---

## Fiche d'exécution

| Champ | Valeur |
|---|---|
| Date/heure | à renseigner |
| Opérateur | à renseigner |
| Branche | `work/integration-deploy` |
| Commit testé | à renseigner |
| Profil(s) lancé(s) | à renseigner |
| État final | à renseigner |

## Matrice de vérification

| Contrôle | Résultat attendu | Observé | Preuve | Correction si échec |
|---|---|---|---|---|
| Git | branche `work/integration-deploy`, arbre propre hors artefacts attendus | à renseigner | `git status --branch` | à renseigner |
| Validation statique | `validate-static.sh` sans erreur | à renseigner | sortie commande | à renseigner |
| OPNsense WAN | `10.85.4.10` configuré | à renseigner | capture | à renseigner |
| NAT 443 | `10.85.4.10:443 → 192.168.10.50:443` | à renseigner | capture + test TCP/TLS | à renseigner |
| Images offline | toutes les images requises présentes | à renseigner | `docker image ls` | à renseigner |
| Réseaux Docker | zones + micro-segments présents | à renseigner | `docker network ls/inspect` | à renseigner |
| Publication | seul E2 publie `192.168.10.50:443:443` | à renseigner | `docker ps` | à renseigner |
| Vhosts | `shop`, `api`, `vendeurs`, `cache` répondent en HTTPS | à renseigner | `curl -vk --resolve` | à renseigner |
| E4 sain | API accessible sans flag volontaire | à renseigner | curl + logs | à renseigner |
| E15 sain | Zabbix déployé en ADMIN, non exposé au WAN | à renseigner | `docker ps/inspect` | à renseigner |
| E16 sain | CRM déployé en SRV, sans flag volontaire | à renseigner | curl/logs internes | à renseigner |
| Chaîne A | `E2 → E7 → E8 → E10` rejouable | à renseigner | commandes + alertes | à renseigner |
| Chaîne B | `E5 → E14 → E12 → E11` rejouable | à renseigner | commandes + alertes | à renseigner |
| Chaîne C | `E3 → E6 → E9 → E13` rejouable | à renseigner | commandes + alertes | à renseigner |
| Détection EveBox | alertes TP visibles pour les étapes critiques | à renseigner | capture EveBox | à renseigner |
| Détection ELK | logs Docker indexés dans Kibana | à renseigner | capture Kibana | à renseigner |
| Persistance des flags | flags encore présents après relance contrôlée | à renseigner | relance + relecture masquée | à renseigner |
| Isolation N3 | aucun N3 accessible directement depuis la DMZ/WAN | à renseigner | tests refusés | à renseigner |

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

## Règle de clôture

La recette n'est complète que lorsque chaque ligne de la matrice comporte un résultat observé, une preuve exploitable, une correction ou une justification en cas d'écart, et l'absence de tout secret réutilisable hors lab dans la documentation finale.

---

**Navigation** : ← [`05-detection.md`](05-detection.md) · Suivant → [`07-endpoints-et-verification.md`](07-endpoints-et-verification.md)
