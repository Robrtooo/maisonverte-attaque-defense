# 05 - Detection

- Suricata inspecte trafic traversant pont L2 vers `vulndb`.
- EveBox : `http://192.168.10.30:5636` depuis pivot interne.
- ELK collecte logs Docker JSON ; trafic intra-hote Docker peut ne pas passer Suricata.
- Kibana : bind local `127.0.0.1:5601`.
- SID locaux : commencer `9000001` ; conserver correspondance SID/etape/alerte.
- Ajouter : regles, sources logs, requetes Kibana, alertes attendues, faux positifs.

