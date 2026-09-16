# 05 - Detection

## Sources

| Source | Role | Limite |
|---|---|---|
| Suricata | preuve reseau officielle | voit le trafic traversant le pont L2, pas forcement les flux intra-hote Docker |
| EveBox | consultation alertes Suricata | accessible depuis pivot interne `http://192.168.10.30:5636` |
| ELK defensif | logs Docker JSON | distinct de E7 vulnerable, Kibana en loopback |
| Logs Docker | traces applicatives par conteneur | dependent des images et healthchecks |

Kibana est publie uniquement en local :

```text
127.0.0.1:5601:5601
```

## Regles Suricata

- Fichier local attendu : `/etc/suricata/rules/tp-local.rules`.
- SID locaux : commencer a `9000001`.
- Conserver une correspondance SID -> etape -> alerte -> preuve.
- Ne pas compter ELK comme remplacement de Suricata ; ELK complete les angles morts Docker.

## Couverture attendue

| Famille | Exemples a couvrir | Preuve a ajouter |
|---|---|---|
| Reconnaissance | scans, vhosts, chemins sensibles | alerte EveBox + paquet/log |
| N1 | E2 nginx, E3 WordPress, E5 Tomcat | alerte par point d'entree |
| Pivots internes | E7, E8, E14, E12, E6, E9 | alerte ou log correle |
| DATA/SHOPS | E10, E11, E13 | flux final + acces flag masque |
| Canaries | `AI-CANARY-*` si presents | alerte sans effet fonctionnel |
| Services sains | E4, E15, E16 | logs montrant acces normal sans flag volontaire |

## ELK

La stack defensive lit `/var/lib/docker/containers/*/*.log` en lecture seule.
Elle ne doit pas utiliser `privileged` ni `docker.sock`. Elle sert a correler :

- requetes HTTP applicatives ;
- erreurs d'exploitation ;
- execution de jobs ;
- connexions aux services internes ;
- healthchecks et redemarrages.

Requetes Kibana a documenter apres terrain :

```text
container.name:"cache-dmz01"
container.name:"market-dmz01" AND message:"PUT"
message:"AI-CANARY"
container.name:"deploy-srv01"
container.name:"pos-consol-shops01"
```

## Tableau de correlation

| Etape | Source reseau | Source log | Statut preuve |
|---|---|---|---|
| E2 fuite nginx | Suricata/EveBox | `cache-dmz01` | a ajouter |
| E3 WordPress | Suricata/EveBox | `shop-dmz01` | a ajouter |
| E5 Tomcat | Suricata/EveBox | `market-dmz01` | a ajouter |
| E7 Elasticsearch | Suricata si flux traverse pont, sinon ELK | `search-srv01` | a ajouter |
| E8 Redis | Suricata si visible, sinon ELK | `cache-srv01` | a ajouter |
| E10 PostgreSQL | Suricata si visible, sinon ELK | `catalog-data01` | a ajouter |
| E14 Jenkins | Suricata si visible, sinon ELK | `deploy-srv01` | a ajouter |
| E12 XXL-JOB | Suricata si visible, sinon ELK | `pos-consol-shops01` | a ajouter |
| E11 Mongo Express | Suricata si visible, sinon ELK | `clients-data01` | a ajouter |
| E6 OFBiz | Suricata si visible, sinon ELK | `backoffice-srv01` | a ajouter |
| E9 Samba | Suricata si visible, sinon ELK | `files-srv01` | a ajouter |
| E13 Struts2 | Suricata si visible, sinon ELK | `wms-shops01` | a ajouter |
