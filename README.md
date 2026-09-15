# MaisonVerte - Attaque / Defense

Depot prive de suivi pour le projet MaisonVerte, profil e-commerce/retail.

Objectif : centraliser les enonces, le cadrage, les schemas et les futurs scripts de deploiement versionnes.

## Structure

- `enonce/` : documents fournis par l'encadrement et fichiers de reference du lab.
- `suivi/` : documents de cadrage equipe, checklist et schema draw.io.
- `deploiement/` : futurs scripts d'installation, segmentes par zone et par service.

## Regle de deploiement

Chaque service installe doit avoir son propre script versionne.

Les scripts seront organises par zone :

- `00-infra/` : firewall, reseaux, prechecks, routage.
- `10-dmz/` : services exposes N1.
- `20-srv/` : services applicatifs et pivots N2.
- `30-data/` : bases de donnees et objectifs DATA.
- `50-admin/` : supervision, detection, administration.
- `60-shops/` : services metier specifiques, dont WMS.
- `90-orchestration/` : scripts permettant de lancer plusieurs installations en parallele.

## Principe

Le depot ne doit pas contenir de secret reel reutilisable hors lab.

Les indices d'exploitation doivent rester limites, plausibles et utiles au scenario, sans ouvrir de raccourci direct vers les objectifs profonds.
