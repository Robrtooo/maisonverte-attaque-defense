# 05 · Détection

*Ce document décrit la chaîne de détection officielle (Suricata/EveBox), son complément ELK, et la couverture attendue pour chaque famille d'attaque.*

---

## Sources

| Source | Rôle | Limite |
|---|---|---|
| Suricata | Preuve réseau officielle | Voit le trafic traversant le pont L2, pas nécessairement les flux intra-hôte Docker |
| EveBox | Consultation des alertes Suricata | Accessible depuis le pivot interne, `http://192.168.10.30:5636` |
| ELK défensif | Logs Docker au format JSON | Distinct de E7 (vulnérable), Kibana en loopback |
| Logs Docker | Traces applicatives par conteneur | Dépendent des images et des healthchecks |

Kibana est publié uniquement en local :

```text
127.0.0.1:5601:5601
```

## Règles Suricata

Le fichier local attendu est `/etc/suricata/rules/tp-local.rules`, avec des SID locaux à partir de `9000001`. Une correspondance SID → étape → alerte → preuve est conservée à jour, et ELK ne remplace jamais Suricata : il en complète les angles morts Docker, sans s'y substituer.

## Couverture attendue

| Famille | Exemples à couvrir | Preuve à ajouter |
|---|---|---|
| Reconnaissance | scans, vhosts, chemins sensibles | alerte EveBox + paquet/log |
| N1 | E2 nginx, E3 WordPress, E5 Tomcat | alerte par point d'entrée |
| Pivots internes | E7, E8, E14, E12, E6, E9 | alerte ou log corrélé |
| DATA/SHOPS | E10, E11, E13 | flux final + accès flag masqué |
| Canaries | `AI-CANARY-*` si présents | alerte sans effet fonctionnel |
| Services sains | E4, E15, E16 | logs montrant un accès normal, sans flag volontaire |

## ELK

La stack défensive lit `/var/lib/docker/containers/*/*.log` en lecture seule, sans jamais utiliser `privileged` ni `docker.sock`. Elle sert à corréler les requêtes HTTP applicatives, les erreurs d'exploitation, l'exécution des jobs, les connexions aux services internes, ainsi que les healthchecks et les redémarrages.

Requêtes Kibana à documenter après le terrain :

```text
container.name:"cache-dmz01"
container.name:"market-dmz01" AND message:"PUT"
message:"AI-CANARY"
container.name:"deploy-srv01"
container.name:"pos-consol-shops01"
```

## Tableau de corrélation

| Étape | Source réseau | Source log | Statut preuve |
|---|---|---|---|
| E2 fuite nginx | Suricata/EveBox | `cache-dmz01` | à ajouter |
| E3 WordPress | Suricata/EveBox | `shop-dmz01` | à ajouter |
| E5 Tomcat | Suricata/EveBox | `market-dmz01` | à ajouter |
| E7 Elasticsearch | Suricata si le flux traverse le pont, sinon ELK | `search-srv01` | à ajouter |
| E8 Redis | Suricata si visible, sinon ELK | `cache-srv01` | à ajouter |
| E10 PostgreSQL | Suricata si visible, sinon ELK | `catalog-data01` | à ajouter |
| E14 Jenkins | Suricata si visible, sinon ELK | `deploy-srv01` | à ajouter |
| E12 XXL-JOB | Suricata si visible, sinon ELK | `pos-consol-shops01` | à ajouter |
| E11 Mongo Express | Suricata si visible, sinon ELK | `clients-data01` | à ajouter |
| E6 OFBiz | Suricata si visible, sinon ELK | `backoffice-srv01` | à ajouter |
| E9 Samba | Suricata si visible, sinon ELK | `files-srv01` | à ajouter |
| E13 Struts2 | Suricata si visible, sinon ELK | `wms-shops01` | à ajouter |

---

**Navigation** : ← [`04-exploitation.md`](04-exploitation.md) · Suivant → [`06-recette.md`](06-recette.md)
