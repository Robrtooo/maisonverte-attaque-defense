# MaisonVerte - avancement deploiement

Derniere mise a jour : 16/09/2026.

Branche de reprise conseillee : `work/integration-deploy`.

## Etat court

- Tasks 1-3 : fermees, revues, poussees. DMZ deja deployee sur `vulndb` au commit `a5d6611` : 15 reseaux, TLS, E2/E3/E4/E5 OK, bind unique `192.168.10.50:443`.
- Task 4 : chaine A E7/E8/E10 scriptee.
- Task 5 : chaine B E14/E12/E11 scriptee. Test statique corrige sur `work/current-task5`.
- Task 6 : chaine C E6/E9/E13 scriptee. Test statique renforce sur `work/current-task6`.
- Task 7 : services sains E15/E16 + donnees metier + workflows R-03/R-04/R-05 scriptes sur `work/current-task7`.
- Task 8 : ELK defensif + scripts detection NSM/Suricata ajoutes sur `work/integration-deploy`.
- Task 9 : orchestration RAM-aware ajoutee sur `work/integration-deploy`.

## RAM / strategie

`vulndb` mesure environ 7.95 Gio RAM. `poste` et `nsm` environ 3.9 Gio.

Ne pas tout demarrer par defaut. Mode conseille :

```bash
deploiement/90-orchestration/deploy-maisonverte.sh poc
deploiement/90-orchestration/deploy-maisonverte.sh chain-a
# ou chain-b / chain-c selon recette
```

`full-risky` existe mais peut saturer selon images et JVM.

## Commandes utiles

Validation statique rapide :

```bash
deploiement/90-orchestration/validate-static.sh
```

Profils :

```bash
deploiement/90-orchestration/deploy-profile.sh foundation
deploiement/90-orchestration/deploy-profile.sh dmz
deploiement/90-orchestration/deploy-profile.sh business
deploiement/90-orchestration/deploy-profile.sh detection
deploiement/90-orchestration/deploy-profile.sh chain-a
deploiement/90-orchestration/deploy-profile.sh chain-b
deploiement/90-orchestration/deploy-profile.sh chain-c
deploiement/90-orchestration/deploy-profile.sh stop-heavy
```

## Images

Les scripts ne font aucun `docker pull`. Images attendues dans `deploiement/config/images.lock`.
ELK ajoute :

- `docker.elastic.co/elasticsearch/elasticsearch:7.17.24`
- `docker.elastic.co/kibana/kibana:7.17.24`
- `docker.elastic.co/beats/filebeat:7.17.24`

Si absentes du lab, preparer/importer bundle hors-lab avant execution detection.

## Detection

- Suricata/EveBox existe sur NSM : `http://192.168.10.30:5636` depuis pivot interne.
- Suricata voit le trafic qui traverse le pont L2 vers `vulndb`.
- Le trafic Docker intra-hote peut ne pas traverser la sonde : ELK collecte donc les logs Docker JSON.
- Kibana publie uniquement `127.0.0.1:5601:5601`.
- E7 vulnerable et ELK defensif sont separes : reseau, volumes, cluster name.

## A verifier en lab

- Presence images ELK.
- Healthchecks JVM lents : E6/E14/E15/ELK peuvent demander 2-4 min.
- Filebeat: verifier ingestion apres premiers logs applicatifs.
- Orchestration `poc`, puis une seule chaine a la fois.

## Regles fixes

- Reseaux externes : `net-dmz`, `net-srv`, `net-data`, `net-users`, `net-admin`, `net-spec`, `mv-a-edge`, `mv-a-core`, `mv-a-data`, `mv-b-edge`, `mv-b-core`, `mv-b-data`, `mv-c-edge`, `mv-c-core`, `mv-c-spec`.
- Flags : E2=1, E3=2, E5=3, E7=4, E8=5, E10=6, E14=7, E12=8, E11=9, E6=10, E9=11, E13=12.
- OPNsense/VLAN/NAT faits main. Scripts ne modifient pas OPNsense.
- E2 seul bind public : `192.168.10.50:443:443`. Kibana loopback seulement.
