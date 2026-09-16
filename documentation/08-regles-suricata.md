# 08 · Règles Suricata

*Liste des règles locales déployées sur `nsm` (`192.168.10.30`), fichier `/etc/suricata/rules/tp-local.rules`. Déployé et validé le 16/09/2026 (`suricata -T` : 0 erreur ; service redémarré, 52613 règles chargées au total avec les 23 nouvelles, 0 échec).*

## Constat important (test réel, 16/09/2026)

E2/E3/E5 sont publiés en TLS (443, nginx par défaut = cipher ECDHE, forward secrecy). Un test réel depuis le VPN a confirmé que :

- Les **signatures de contenu HTTP** (traversal `/files../`, user-agent `sqlmap`, en-tête canary `AI-CANARY-*`, etc.) **ne se déclenchent pas** sur ce trafic : Suricata ne peut pas inspecter un contenu chiffré sans les clés de session, et la capture passive de clé RSA ne fonctionne pas avec ECDHE/TLS 1.3. Ces règles restent dans le fichier (documentent la logique de détection attendue, s'activeraient sur un flux en clair) mais **ne doivent pas être présentées comme preuve réseau** pour les services servis derrière E2.
- Les **règles SNI TLS** (9000026-9000029, ajoutées suite à ce constat) **se sont bien déclenchées** : test à 10:58:48 le 16/09/2026, alertes `MV N1 TLS SNI shop.maisonverte.fr`, `vendeurs.maisonverte.fr` et `cache.maisonverte.fr` vues dans `fast.log` pour la source `10.200.0.67` (poste VPN) vers `192.168.10.50:443`. C'est la détection réseau fiable pour le trafic N1 réel.
- **Preuve applicative** (contenu réel de la requête/exploit) : à chercher dans les logs des conteneurs via ELK/Filebeat (ex. access log nginx d'E2), qui voient le trafic en clair après déchiffrement côté conteneur — pas dans Suricata pour ce qui passe par E2.

---

## Socle plateforme (non modifié)

Ces 6 règles existaient déjà dans le fichier avant notre intervention — fournies par la plateforme comme base commune à tous les groupes. On ne les a pas touchées pour éviter toute collision de SID.

| SID | Message | Déclencheur |
|---|---|---|
| 9000001 | ICMP echo request vers le segment protégé | ping vers `vulndb`/segment protégé |
| 9000002 | Marqueur de test (URI `/tp-suricata-test`) | requête HTTP de test |
| 9000003 | Connexion MySQL/MariaDB vers le segment protégé | connexion TCP/3306 |
| 9000004 | Connexion Redis (sans authentification) vers le segment protégé | connexion TCP/6379 |
| 9000005 | Injection SQL probable (UNION SELECT dans l'URI) | motif générique dans l'URI |
| 9000006 | Balayage de ports probable (SYN vers >15 ports en 10s) | scan TCP |

## Règles MaisonVerte (groupe G04) — ajoutées le 16/09/2026

### Reconnaissance

| SID | Message | Déclencheur |
|---|---|---|
| 9000007 | User-agent `sqlmap` | en-tête `User-Agent` HTTP |
| 9000008 | User-agent `Nikto` | en-tête `User-Agent` HTTP |
| 9000009 | Outil de brute-force de répertoires (gobuster/dirbuster/ffuf/wfuzz) | en-tête `User-Agent` HTTP |

### N1 — points d'entrée (E2, E3, E5)

| SID | Service | Message | Déclencheur |
|---|---|---|---|
| 9000010 | E2 | nginx alias path traversal (`/files../`) | URI HTTP |
| 9000011 | E3 | WordPress pwnscriptum, injection de commande via en-tête Host (`${run{`) | URI `/wp-login.php` + en-tête Host |
| 9000012 | E5 | Tomcat PUT JSP (CVE-2017-12615) | méthode PUT + URI se terminant par `.jsp` |

### Pivots internes (E6, E7, E8, E9, E12, E14)

| SID | Service | Message | Déclencheur |
|---|---|---|---|
| 9000013 | E7 | Elasticsearch RCE via script groovy (CVE-2015-1427) | URI `_search` + corps `"lang":"groovy"` |
| 9000014 | E8 | Redis SLAVEOF/REPLICAOF (prise de contrôle rogue master) | commande Redis `SLAVEOF` |
| 9000015 | E8 | Redis MODULE LOAD | commandes Redis `MODULE` + `LOAD` |
| 9000016 | E14 | Jenkins — téléchargement `jenkins-cli.jar` (reconnaissance CVE-2024-23897) | URI `/jnlpJars/jenkins-cli.jar` |
| 9000017 | E14 | Jenkins CLI — lecture de fichier arbitraire (`@/chemin`) | URI `/cli` + corps contenant `@/` |
| 9000018 | E12 | XXL-JOB executor — RCE `GLUE_SHELL` non authentifiée | URI `/run` (port 9999) + corps `GLUE_SHELL` |
| 9000019 | E11 | mongo-express `/checkValid` RCE (CVE-2019-10758) | URI `/checkValid` + corps `constructor.constructor` |
| 9000020 | E6 | OFBiz `ProgramExport` — contournement d'authentification (CVE-2023-51467) | URI `/webtools/control/ProgramExport` + `USERNAME=` |
| 9000021 | E9 | Samba — écriture d'un objet `.so` sur le partage (préalable CVE-2017-7494) | contenu TCP/445 |
| 9000022 | E13 | Struts2 S2-045 — OGNL dans l'en-tête Content-Type | en-têtes HTTP : `multipart/form-data` + `%{` |

### DATA / SHOPS — objectifs finaux

| SID | Service | Message | Déclencheur |
|---|---|---|---|
| 9000023 | E10 | PostgreSQL `COPY FROM PROGRAM` (CVE-2019-9193) | contenu TCP/5432 : `COPY` + `PROGRAM` |

### Leurres / canary IA

| SID | Message | Déclencheur |
|---|---|---|
| 9000024 | Jeton de prompt-injection IA utilisé (`AI-CANARY-*`) | contenu HTTP `AI-CANARY-` |

### Violation d'isolation

| SID | Message | Déclencheur |
|---|---|---|
| 9000025 | Accès direct poste → port interne normalement non joignable | source `192.168.10.10` (poste) vers `5432/27017/6379/9200/445/9999/8443` |

### Visibilité N1 fiable — SNI TLS (fonctionne malgré le chiffrement)

| SID | Service | Message | Statut |
|---|---|---|---|
| 9000026 | E2 | SNI `cache.maisonverte.fr` | **Déclenchée et vérifiée** 16/09/2026 10:58:48 |
| 9000027 | E3 | SNI `shop.maisonverte.fr` | **Déclenchée et vérifiée** 16/09/2026 10:58:48 |
| 9000028 | E5 | SNI `vendeurs.maisonverte.fr` | **Déclenchée et vérifiée** 16/09/2026 10:58:48 |
| 9000029 | E4 (sain) | SNI `api.maisonverte.fr` | non testée (service sain, pas prioritaire) |

---

## Limite connue

La sonde `nsm` est un pont L2 transparent entre le segment « poste » et `vulndb` : elle voit tout le trafic qui atteint `vulndb` (y compris le trafic externe N1 via le NAT OPNsense), mais **pas** le trafic qui reste interne aux réseaux Docker de `vulndb` (la plupart des pivots N2/N3 après E2/E3/E5). E2/E3/E5 sont servis en TLS (443) : les signatures de contenu HTTP ci-dessus ne matchent que si l'inspection se fait en clair (tests locaux, ou découverte d'un service annexe en HTTP) ; le SNI TLS reste visible dans tous les cas et permet déjà de savoir quel vhost est ciblé. ELK/Filebeat (logs applicatifs des conteneurs) complète la visibilité que Suricata n'a pas sur ces flux — voir [`05-detection.md`](05-detection.md).

## Déploiement

- Fichier : `/etc/suricata/rules/tp-local.rules` sur `nsm` (`192.168.10.30`).
- Sauvegarde de l'ancien fichier (socle plateforme seul) : `/etc/suricata/rules/tp-local.rules.bak-20260916`.
- Validation : `sudo suricata -T -c /etc/suricata/suricata.yaml` → 0 erreur.
- Application : `sudo systemctl restart suricata` → 52613 règles chargées, 0 échec (dernière itération avec les règles SNI).
- Copie versionnée du fichier déployé : [`deploiement/80-detection/tp-local.rules`](../deploiement/80-detection/tp-local.rules).

## Reste à faire

Déclencher chaque règle au moins une fois en conditions réelles (rejeu des chaînes A/B/C) et capturer la preuve dans EveBox (`http://192.168.10.30:5636/`), à consigner dans le document pédagogique §7b et dans [`05-detection.md`](05-detection.md).

---

**Navigation** : ← [`07-endpoints-et-verification.md`](07-endpoints-et-verification.md)
