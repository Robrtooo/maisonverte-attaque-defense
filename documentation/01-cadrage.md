# 01 · Cadrage

*Ce document définit l'objectif du POC, son périmètre exact et les contraintes imposées par le lab. C'est le point de départ à lire avant tout le reste.*

---

## Objectif

MaisonVerte est un POC attaque/défense pour un SI e-commerce/retail. Le but est de fournir un environnement réaliste, volontairement vulnérable sur des points choisis, observable par la blue team et rejouable en recette.

## Périmètre

Le périmètre couvre les seize services E1 à E16, dont douze vulnérables, issus de scénarios Vulhub intégrés au TP. Trois points d'entrée N1 sont exposés — E2, E3 et E5 — et au moins deux chaînes complètes N1 → N2 → N3 doivent être rejouables, les chaînes A et B restant prioritaires. La détection officielle repose sur Suricata/EveBox, complétée par ELK pour les logs Docker, et les flags doivent persister après une relance contrôlée.

### Services sains

| Réf | Rôle | Statut |
|---|---|---|
| E1 | OPNsense, bordure réseau | configuration manuelle |
| E4 | API mobile publique | sain |
| E15 | supervision Zabbix | sain |
| E16 | CRM/campagnes | sain |

## Contraintes lab

Le lab est intégralement hors ligne : aucun script ne doit lancer `docker pull`, `apt-get`, `apk add`, `pip install`, `npm install`, `git clone` ni `suricata-update`. Il n'y a ni DNS ni DHCP, les noms publics passant uniquement par `/etc/hosts`. OPNsense, les VLAN, le routage, le NAT et le filtrage sont configurés à la main, sans qu'aucun script n'y touche. L'hôte Docker `vulndb` (`192.168.10.50`) dispose d'environ 7,95 Gio de RAM mesurée ; le NSM/EveBox répond sur `192.168.10.30:5636`, et le poste de pivot se trouve à `10.85.4.20`.

## Rôles de documentation

| Rôle | Responsabilité |
|---|---|
| Attaquant | Décrire uniquement les chemins autorisés du TP, avec préconditions et preuves. |
| Défenseur | Associer chaque étape critique à une alerte, un log ou une limite de visibilité documentée. |
| Builder | Conserver les commandes de déploiement, les profils utilisés, les commits et les corrections apportées. |
| Recette | Noter résultat attendu, résultat observé, preuve et correction en cas d'échec. |

## État connu au 16/09/2026

Au 16/09/2026, `deploiement/PROGRESS.md` indique les tâches 1 à 9 comme scriptées ou intégrées, et la DMZ comme déjà déployée sur `vulndb` au commit `a5d6611`. Les autres preuves de terrain restent à ajouter après exécution de la recette.

---

**Navigation** : ← [`00-structure-preuves.md`](00-structure-preuves.md) · Suivant → [`02-architecture.md`](02-architecture.md)
