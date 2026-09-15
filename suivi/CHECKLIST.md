# MaisonVerte - checklist de suivi

## Decisions figees

- [ ] 12 vulnerabilites Vulhub.
- [ ] 3 N1 seulement : E2, E3, E5.
- [ ] E4 API mobile sain.
- [ ] E15 ADMIN/Zabbix sain.
- [ ] E16 CRM sain.
- [ ] Deux chaines prioritaires : A et B.
- [ ] Prompt injection/canary IA limitee, pas partout.

## Infra lab

- [ ] Configurer `10.85.4.10` sur FW WAN.
- [ ] Verifier acces `10.85.4.20`.
- [ ] Verifier pivot vers `192.168.10.0/24`.
- [ ] Verifier EveBox `192.168.10.30:5636`.
- [ ] Verifier vulndb `192.168.10.50`.

## Reseaux Docker

- [ ] `net-dmz` / `172.30.10.0/24`.
- [ ] `net-srv` / `172.30.20.0/24`.
- [ ] `net-data` / `172.30.30.0/24`.
- [ ] `net-users` / `172.30.40.0/24`.
- [ ] `net-admin` / `172.30.50.0/24`.
- [ ] `net-spec` / `172.30.60.0/24`.

## Vulhub a tester en premier

- [ ] E2 : [`nginx/insecure-configuration`](https://github.com/vulhub/vulhub/tree/master/nginx/insecure-configuration).
- [ ] E3 : [`wordpress/pwnscriptum`](https://github.com/vulhub/vulhub/tree/master/wordpress/pwnscriptum).
- [ ] E5 : [`tomcat/CVE-2017-12615`](https://github.com/vulhub/vulhub/tree/master/tomcat/CVE-2017-12615).
- [ ] E6 : [`ofbiz/CVE-2023-51467`](https://github.com/vulhub/vulhub/tree/master/ofbiz/CVE-2023-51467).
- [ ] E7 : [`elasticsearch/CVE-2015-1427`](https://github.com/vulhub/vulhub/tree/master/elasticsearch/CVE-2015-1427).
- [ ] E8 : [`redis/4-unacc`](https://github.com/vulhub/vulhub/tree/master/redis/4-unacc).
- [ ] E9 : [`samba/CVE-2017-7494`](https://github.com/vulhub/vulhub/tree/master/samba/CVE-2017-7494).
- [ ] E10 : [`postgres/CVE-2019-9193`](https://github.com/vulhub/vulhub/tree/master/postgres/CVE-2019-9193).
- [ ] E11 : [`mongo-express/CVE-2019-10758`](https://github.com/vulhub/vulhub/tree/master/mongo-express/CVE-2019-10758).
- [ ] E12 : [`xxl-job/unacc`](https://github.com/vulhub/vulhub/tree/master/xxl-job/unacc).
- [ ] E13 : [`struts2/s2-045`](https://github.com/vulhub/vulhub/tree/master/struts2/s2-045).
- [ ] E14 : [`jenkins/CVE-2024-23897`](https://github.com/vulhub/vulhub/tree/master/jenkins/CVE-2024-23897).

## Chaines

- [ ] Chaine A : `E2 -> E7 -> E8 -> E10`.
- [ ] Chaine A : prevoir sur E2 un indice naturel qui revele la recherche interne sans exposer directement E7 depuis WAN.
- [ ] Chaine B : `E5 -> E14 -> E12 -> E11`.
- [ ] Chaine C : `E3 -> E6 -> E9 -> E13` si temps.

## Verification critique

- [ ] Depuis WAN, seuls E2, E3, E5 sont exploitables.
- [ ] E4 n'est pas vulnerable.
- [ ] E15 n'est pas accessible depuis les zones internes hors collecte.
- [ ] Aucun N3 direct depuis DMZ.
- [ ] Chaque credential ouvre un seul service.
- [ ] Chaque flag survit au reboot.

## Blue team

- [ ] `tp-local.rules` cree.
- [ ] SID a partir de `9000001`.
- [ ] Regles N1.
- [ ] Regles mouvements lateraux.
- [ ] Regles DATA/SHOPS.
- [ ] Regles canary `AI-CANARY-*`.
- [ ] Chaque regle declenchee dans EveBox.
