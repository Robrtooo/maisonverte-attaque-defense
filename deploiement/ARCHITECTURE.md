# Architecture de deploiement MaisonVerte

## Objectif

Deployer de facon rejouable la tranche ferme E1-E16 du CDC MaisonVerte, dont
12 services Vulhub exploitables, trois points d'entree N1, trois chaines
controlees, des donnees metier coherentes et une detection Suricata/EveBox +
ELK. Tous les scripts sont rediges et revus avant leur premiere execution sur
le lab.

## Autorites et perimetre

- Le CDC MaisonVerte prime pour les besoins metier.
- Le socle technique prime pour les choix de mise en oeuvre.
- La grille de recette definit les preuves obligatoires.
- E1 OPNsense, les VLAN, le routage, le NAT et le filtrage sont configures a
  la main. Les scripts ne font qu'imprimer le plan et verifier le resultat.
- Les scripts automatisent l'hote Docker, E2-E16, les donnees, les flags, les
  regles Suricata locales, ELK et les controles de recette.
- Aucun script n'utilise Internet dans le lab. Aucun `docker pull`, `apt-get`
  ou `suricata-update` n'est lance par un script de deploiement.

## Publication

L'unique publication externe est `10.85.4.10:443`. OPNsense la redirige vers
`192.168.10.50:443`, ou E2 termine TLS et distribue les requetes selon SNI et
l'en-tete Host :

| Nom public | Destination | Statut |
|---|---|---|
| `shop.maisonverte.fr` | E3 WordPress | N1 vulnerable |
| `api.maisonverte.fr` | E4 API mobile | sain |
| `vendeurs.maisonverte.fr` | E5 Tomcat | N1 vulnerable |
| `cache.maisonverte.fr` | E2 nginx | N1 vulnerable |

Le Document Attaquant indiquera les lignes `/etc/hosts` vers `10.85.4.10`.
E2 preserve les methodes, URI, corps et en-tetes necessaires aux exploits de
E3 et E5. E2 n'offre qu'une fuite d'information par alias nginx ; il ne donne
pas de shell.

## Reseaux Docker

Les six zones du socle sont creees et documentees :

| Zone | Reseau | Sous-reseau |
|---|---|---|
| DMZ | `net-dmz` | `172.30.10.0/24` |
| SRV | `net-srv` | `172.30.20.0/24` |
| DATA | `net-data` | `172.30.30.0/24` |
| USERS | `net-users` | `172.30.40.0/24` |
| ADMIN | `net-admin` | `172.30.50.0/24` |
| SHOPS | `net-spec` | `172.30.60.0/24` |

Des micro-segments internes supplementaires rendent les chaines verifiables
sans raccourci. Ils sont des sous-zones techniques, jamais publiees sur
l'hote :

| Chaine | Micro-segments | Maillons |
|---|---|---|
| A | `mv-a-edge`, `mv-a-core`, `mv-a-data` | E2-E7, E7-E8, E8-E10 |
| B | `mv-b-edge`, `mv-b-core`, `mv-b-data` | E5-E14, E14-E12, E12-E11 |
| C | `mv-c-edge`, `mv-c-core`, `mv-c-spec` | E3-E6, E6-E9, E9-E13 |

Les bases auxiliaires de WordPress, mongo-express et XXL-JOB disposent de
reseaux backend prives propres. Un conteneur multi-reseau correspond toujours
a un maillon de proxy ou de pivot documente.

## Services et vulnerabilites

| Ref | Conteneur principal | Zone logique | Niveau | Image/scenario |
|---|---|---|---|---|
| E1 | OPNsense fourni | bordure | sain | configuration manuelle |
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
| E16 | `crm-srv01` | SRV | sain | application CRM legere |

Les conteneurs MySQL/MongoDB requis par certains scenarios sont des
dependances techniques et ne remplacent aucun service E1-E16. Aucun port de
backend, JDWP, transport Elasticsearch, agent Jenkins ou bind shell Samba
n'est publie sur l'hote.

## Chaines imposees

- A : E2 fuite la route et le jeton de recherche, E7 revele E8, E8 revele le
  compte PostgreSQL unique, E10 contient le flag final.
- B : E5 revele le chemin Jenkins, E14 revele E12, E12 revele le compte
  mongo-express, E11 contient le flag clients.
- C : E3 revele E6, E6 revele le partage E9, E9 contient la procedure WMS,
  E13 contient le flag logistique.

La chaine C est obligatoire au deploiement meme si seules deux chaines sont
requises par la notation. Chaque information de pivot ouvre une seule porte.

## Flags et secrets

- Les douze valeurs proviennent uniquement de `enonce/flags-G04.csv`.
- Les scripts resolvent un `flag_id` au moment du deploiement ; aucune valeur
  de flag n'est dupliquee dans le code ou dans un fichier Compose.
- La correspondance service/flag est centralisee dans `config/flags.map`.
- Les secrets runtime sont generes dans `state/secrets/`, exclu de Git, avec
  des permissions restrictives.
- Les flags sont injectes par bind exact, init idempotent ou volume nomme et
  survivent a `docker compose down` puis `up -d`.

## Donnees et parcours metier

Les seeds versionnes contiennent au minimum 40 produits, 60 commandes sur
trois mois, 30 clients avec fidelite, 200 lignes de tickets de caisse, huit
vendeurs, des exports comptables dates et les comptes du CDC. Aucune donnee
bancaire reelle n'est presente.

Trois scripts de demonstration produisent les preuves fonctionnelles :

- une commande est creee pour la boutique, reprise dans le back-office puis
  dans une preparation WMS ;
- la recherche E7 retourne les memes references que le catalogue E10 ;
- un lot de ventes magasin alimente E12 puis un export comptable E9.

Ces flux sont deterministes, idempotents et journalises. Ils simulent les
interfaces d'une maquette sans construire un ERP complet.

## Detection

Suricata/EveBox reste la preuve reseau officielle. Les regles locales sont
installees dans `/etc/suricata/rules/tp-local.rules`, avec des SID a partir de
`9000001`. Elles couvrent reconnaissance, N1, SNI publics et canaries. La
sonde physique ne voit pas les echanges intra-hote entre bridges Docker ; ce
point est compense par les journaux applicatifs.

La stack defensive ELK est distincte d'E7 et composee d'Elasticsearch,
Kibana, Logstash et Filebeat de meme version. Elle reside uniquement dans
ADMIN. Filebeat lit `/var/lib/docker/containers/*/*.log` en lecture seule,
sans `privileged` ni `docker.sock`. Kibana est lie a `127.0.0.1:5601`,
Elasticsearch n'est pas publie, la retention est de sept jours et les logs
Docker tournent a `10m x 3`.

## Offline et ressources

Mesures du lab au 15/09/2026 : `vulndb` dispose de 7.95 Gio de RAM et heberge
les projets Compose ; `poste` et `nsm` disposent chacun de 3.9 Gio. NSM reste
reserve a Suricata/EveBox et le poste au pivot.

La DMZ est plafonnee a 1.984 Gio. Garder au moins 2 Gio de marge sur `vulndb`.
En exploitation, conserver la DMZ et activer une seule chaine A, B ou C a la
fois. ELK envoie Filebeat directement vers Elasticsearch, sans Logstash.

- Toutes les images sont epinglees dans `config/images.lock` et utilisent
  `pull_policy: never`.
- `prepare-offline-bundle.sh` s'execute uniquement sur une machine connectee
  et produit des archives + sommes SHA-256.
- `import-offline-images.sh` est le seul chemin d'import dans le lab.
- Le preflight verifie architecture amd64, images, espace disque, RAM,
  ports, Docker Compose et fichiers de configuration.
- OFBiz et les autres JVM ont des limites memoire. Un profil reduit ajuste
  les limites sans supprimer de service ni desactiver ELK.

## Strategie de scripts

Chaque service E2-E16 possede un script `install-eX-*.sh`. Les scripts sont
relancables, utilisent une bibliotheque commune, ne telechargent rien et
lancent leur projet Compose avec un nom stable. Les orchestrateurs appellent
les scripts unitaires ; ils ne reimplementent pas leur logique.

## Validation avant execution

La revue statique doit verifier : syntaxe Bash, rendu Compose, absence de
tags `latest`, absence de `privileged`, `network_mode: host`, `docker.sock`,
ports hote interdits, couverture des 15 services, douze mappings de flags,
SID uniques, healthchecks, volumes, rotation des logs et scripts de preuve.

La premiere execution sur le lab reste une phase separee. Elle ne commence
qu'apres redaction de tous les scripts, revue par lot, revue globale et push
de la branche sur GitHub.
