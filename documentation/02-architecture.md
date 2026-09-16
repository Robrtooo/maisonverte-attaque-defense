# 02 · Architecture

*Ce document décrit la topologie réelle du lab, le modèle de publication externe, le découpage réseau Docker et l'inventaire complet des 16 services.*

---

## Topologie du lab

| Élément | Adresse / rôle |
|---|---|
| Réseau exposition | `10.85.4.0/24` |
| OPNsense WAN | `10.85.4.10` |
| Poste / pivot | `10.85.4.20` |
| Réseau interne | `192.168.10.0/24` |
| OPNsense LAN | `192.168.10.1` |
| NSM / EveBox | `192.168.10.30:5636` |
| Hôte Docker `vulndb` | `192.168.10.50` |

Suricata est placé sur un pont L2 entre VLAN 10 et VLAN 11. Il observe le trafic qui traverse ce pont vers `vulndb`.

> **Limite de visibilité** — les flux intra-hôte entre bridges Docker peuvent échapper à cette sonde. ELK couvre alors les logs applicatifs pour combler cet angle mort (voir [`05-detection.md`](05-detection.md)).

## Publication externe

Une seule publication externe est prévue :

```text
10.85.4.10:443 → OPNsense NAT → 192.168.10.50:443 → E2
```

E2 termine le TLS et route selon le SNI/Host :

| Nom public | Destination | Statut TP |
|---|---|---|
| `shop.maisonverte.fr` | E3 WordPress | N1 |
| `api.maisonverte.fr` | E4 API mobile | sain |
| `vendeurs.maisonverte.fr` | E5 Tomcat | N1 |
| `cache.maisonverte.fr` | E2 nginx | N1 |

Le document attaquant devra ajouter ces noms vers `10.85.4.10` dans `/etc/hosts`. Aucun backend N2/N3 ne doit être publié directement.

## Réseaux Docker

### Zones

| Zone | Réseau | Sous-réseau |
|---|---|---|
| DMZ | `net-dmz` | `172.30.10.0/24` |
| SRV | `net-srv` | `172.30.20.0/24` |
| DATA | `net-data` | `172.30.30.0/24` |
| USERS | `net-users` | `172.30.40.0/24` |
| ADMIN | `net-admin` | `172.30.50.0/24` |
| SHOPS | `net-spec` | `172.30.60.0/24` |

### Micro-segments de chaîne

| Chaîne | Micro-segments | Maillons |
|---|---|---|
| A | `mv-a-edge`, `mv-a-core`, `mv-a-data` | E2 → E7, E7 → E8, E8 → E10 |
| B | `mv-b-edge`, `mv-b-core`, `mv-b-data` | E5 → E14, E14 → E12, E12 → E11 |
| C | `mv-c-edge`, `mv-c-core`, `mv-c-spec` | E3 → E6, E6 → E9, E9 → E13 |

## Inventaire des services

| Réf | Conteneur principal | Zone | Niveau | Scénario |
|---|---|---|---|---|
| E1 | OPNsense | bordure | sain | configuration manuelle |
| E2 | `cache-dmz01` | DMZ | N1 | `nginx/insecure-configuration` |
| E3 | `shop-dmz01` | DMZ | N1 | `wordpress/pwnscriptum` |
| E4 | `mobile-dmz01` | DMZ | sain | API statique nginx |
| E5 | `market-dmz01` | DMZ | N1 | `tomcat/CVE-2017-12615` |
| E6 | `backoffice-srv01` | SRV | N2 | `ofbiz/CVE-2023-51467` |
| E7 | `search-srv01` | SRV | N2 | `elasticsearch/CVE-2015-1427` |
| E8 | `cache-srv01` | SRV | N2 | `redis/4-unacc` |
| E9 | `files-srv01` | SRV | N2 | `samba/CVE-2017-7494` |
| E10 | `catalog-data01` | DATA | N3 | `postgres/CVE-2019-9193` |
| E11 | `clients-data01` | DATA | N3 | `mongo-express/CVE-2019-10758` |
| E12 | `pos-consol-shops01` | SHOPS | N3 | `xxl-job/unacc` |
| E13 | `wms-shops01` | SHOPS | N3 | `struts2/s2-045` |
| E14 | `deploy-srv01` | SRV | N2 | `jenkins/CVE-2024-23897` |
| E15 | `supervision-admin01` | ADMIN | sain | Zabbix appliance |
| E16 | `crm-srv01` | SRV | sain | CRM léger |

Les scénarios Vulhub ci-dessus sont les failles intentionnelles du TP. Les autres comportements éventuels des images ne sont pas des objectifs de recette.

## Chaînes imposées

Trois chaînes structurent l'exploitation. Dans la chaîne A, E2 révèle la route et le jeton de recherche, E7 révèle E8, E8 révèle le compte PostgreSQL, et E10 contient le flag final. Dans la chaîne B, E5 révèle le chemin Jenkins, E14 révèle E12, E12 révèle le compte Mongo Express, et E11 contient le flag clients. Dans la chaîne C, E3 révèle E6, E6 révèle le partage E9, E9 contient la procédure WMS, et E13 contient le flag logistique.

## À ajouter après recette

Restent à ajouter après la recette : l'export ou la capture du schéma final `suivi/schema-maisonverte.drawio`, une capture OPNsense montrant le NAT, les VLAN et les règles actives, la sortie de `docker network inspect` sur les zones et micro-segments, et un `docker ps` prouvant que seul `192.168.10.50:443:443` est publié, Kibana restant en loopback.

---

**Navigation** : ← [`01-cadrage.md`](01-cadrage.md) · Suivant → [`03-deploiement.md`](03-deploiement.md)
