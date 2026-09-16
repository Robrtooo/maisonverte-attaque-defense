# 07 · Endpoints et vérification

*Ce document liste tous les points d'accès du SI — publics, défense, internes — et la commande unique pour vérifier l'ensemble du déploiement en un coup.*

---

## Vérification globale

À exécuter depuis `vulndb` :

```bash
cd /home/etudiant/maisonverte-attaque-defense
./deploiement/90-orchestration/check-all-services.sh
```

Pour n'afficher que l'inventaire des endpoints :

```bash
./deploiement/90-orchestration/check-all-services.sh --list
```

Le script est en lecture seule : il contrôle les 24 conteneurs, leurs healthchecks, le NAT/TLS, EveBox, Kibana, les jeux de données et l'ingestion ELK. Il retourne `0` si tout passe, `1` sinon.

## Accès public via VPN

Il n'y a pas de DNS dans le lab. Depuis un terminal, `curl --resolve` suffit ; depuis un navigateur, il faut ajouter temporairement ces lignes dans `/etc/hosts` :

```text
10.85.4.10 shop.maisonverte.fr api.maisonverte.fr vendeurs.maisonverte.fr cache.maisonverte.fr
```

| Service | URL | Destination |
|---|---|---|
| E3 Boutique | `https://shop.maisonverte.fr/` | OPNsense `10.85.4.10:443` → E2 → E3 `:80` |
| E4 API mobile | `https://api.maisonverte.fr/health` | OPNsense `10.85.4.10:443` → E2 → E4 `:80` |
| E5 Vendeurs | `https://vendeurs.maisonverte.fr/` | OPNsense `10.85.4.10:443` → E2 → E5 `:8080` |
| E2 Cache/proxy | `https://cache.maisonverte.fr/` | OPNsense `10.85.4.10:443` → E2 `:443` |

Exemple sans modifier le DNS local :

```bash
curl -k --resolve shop.maisonverte.fr:443:10.85.4.10 https://shop.maisonverte.fr/
```

## Défense

| Service | URL/port | Accès |
|---|---|---|
| EveBox / Suricata | `http://192.168.10.30:5636/` | depuis le pivot / réseau interne |
| Kibana | `http://127.0.0.1:5601/` | loopback de `vulndb`, donc tunnel SSH requis |
| Elasticsearch ELK | `elk-admin01-es:9200` | réseau Docker `net-admin` uniquement |

## Services internes

Ces endpoints ne sont pas publiés sur `192.168.10.50` : ils ne sont joignables que depuis un conteneur relié au bon réseau Docker.

| Réf | Service | Endpoint interne |
|---|---|---|
| E6 | OFBiz | `https://backoffice-srv01:8443` |
| E7 | Elasticsearch vulnérable | `http://search-srv01:9200` |
| E8 | Redis | `cache-srv01:6379` |
| E9 | Samba | `files-srv01:445` |
| E10 | PostgreSQL | `catalog-data01:5432` |
| E11 | mongo-express | `http://clients-data01:8081/` |
| E12 | XXL-Job admin | `http://pos-consol-shops01-admin:8080/xxl-job-admin` |
| E12 | XXL-Job executor | `pos-consol-shops01:9999` |
| E13 | Struts2 WMS | `http://wms-shops01:8080/` |
| E14 | Jenkins | `http://deploy-srv01:8080/jenkins` |
| E15 | Zabbix Web | `http://supervision-admin01:8080/` |
| E15 | Zabbix Server | `supervision-admin01-server:10051` |
| E16 | CRM | `http://crm-srv01/health` |

Les bases auxiliaires (`shop-dmz01-db`, `clients-data01-mongo`, `pos-consol-shops01-db`, `supervision-admin01-db`) restent sur des réseaux Docker privés, jamais exposées au-delà de leur propre service.

---

**Navigation** : ← [`06-recette.md`](06-recette.md) · [`00-structure-preuves.md`](00-structure-preuves.md)
