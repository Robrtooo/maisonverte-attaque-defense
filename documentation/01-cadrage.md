# 01 - Cadrage

## Objectif

MaisonVerte est un POC attaque-defense pour un SI e-commerce/retail. Le but
est de fournir un environnement realiste, volontairement vulnerable sur des
points choisis, observable par la blue team et rejouable en recette.

## Perimetre

- 16 services E1-E16.
- 12 services vulnerables issus de scenarios Vulhub integres au TP.
- 3 points d'entree N1 : E2, E3 et E5.
- Au moins deux chaines completes N1 -> N2 -> N3 ; A et B sont prioritaires.
- Detection officielle par Suricata/EveBox, completee par ELK pour les logs Docker.
- Flags persistants apres relance controlee.

Services sains :

| Ref | Role | Statut |
|---|---|---|
| E1 | OPNsense, bordure reseau | configuration manuelle |
| E4 | API mobile publique | sain |
| E15 | supervision Zabbix | sain |
| E16 | CRM/campagnes | sain |

## Contraintes lab

- Lab offline : pas de `docker pull`, `apt-get`, `apk add`, `pip install`, `npm install`, `git clone` ni `suricata-update` dans les scripts de lab.
- Pas de DNS ni DHCP ; les noms publics passent par `/etc/hosts`.
- OPNsense, VLAN, routage, NAT et filtrage sont configures a la main.
- Hote Docker `vulndb` : `192.168.10.50`, RAM mesuree environ 7.95 Gio.
- NSM/EveBox : `192.168.10.30:5636`.
- Poste/pivot : `10.85.4.20`.

## Roles de documentation

- Attaquant : decrire uniquement les chemins autorises du TP, avec preconditions et preuves.
- Defenseur : associer chaque etape critique a une alerte, un log ou une limite de visibilite.
- Builder : conserver les commandes de deploiement, profils, commits et corrections.
- Recette : noter resultat attendu, resultat observe, preuve et correction si echec.

## Etat connu au 16/09/2026

- `deploiement/PROGRESS.md` indique tasks 1 a 9 scriptees ou integrees.
- La DMZ est indiquee comme deja deployee sur `vulndb` au commit `a5d6611`.
- Les autres preuves terrain doivent etre ajoutees apres execution de recette.
