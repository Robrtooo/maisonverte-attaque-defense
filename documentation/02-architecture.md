# 02 - Architecture

- Exposition : `10.85.4.0/24`; OPNsense WAN `10.85.4.10`; poste `10.85.4.20`.
- Interne : `192.168.10.0/24`; VLAN 10/11; pont Suricata transparent.
- NSM/EveBox : `192.168.10.30:5636`; `vulndb` : `192.168.10.50`.
- E2 seul service public : HTTPS `443`, reverse-proxy/TLS.
- Reseaux Docker : DMZ, SRV, DATA, ADMIN, USERS, SPEC + reseaux prives de chaines.
- Chaine A : E7 Elasticsearch, E8 Redis, E10 PostgreSQL.
- Chaine B : E14 Jenkins, E12 XXL-JOB, E11 Mongo Express.
- Chaine C : E6 OFBiz, E9 Samba, E13 Struts2.
- Services sains : E4 API, E15 Zabbix, E16 CRM.
- Ajouter : draw.io final, flux autorises, NAT/rules OPNsense reels.

