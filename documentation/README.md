# Documentation MaisonVerte

Documentation equipe pour la recette et la restitution MaisonVerte.

## Ordre de lecture

1. `00-structure-preuves.md` : structure cible et preuves a collecter.
2. `01-cadrage.md` : objectif, perimetre et contraintes.
3. `02-architecture.md` : topologie, publication, services et chaines.
4. `03-deploiement.md` : preconditions et ordre de lancement.
5. `04-exploitation.md` : chemins d'attaque attendus.
6. `05-detection.md` : Suricata/EveBox, ELK, SID et journaux.
7. `06-recette.md` : matrice de verification.
8. `07-endpoints-et-verification.md` : URLs, ports et controle global.

## Sources de reference

- `deploiement/ARCHITECTURE.md` : source principale pour l'architecture cible.
- `deploiement/PROGRESS.md` : etat courant de scriptage et consignes RAM.
- `suivi/SUIVI.md` et `suivi/CHECKLIST.md` : decisions et suivi equipe.
- `enonce/` : documents d'encadrement, grille, profils, socle et flags.

## Regles

- Garder contenu court, factuel et aligne sur `deploiement/ARCHITECTURE.md`.
- Distinguer "scripte", "verifie statiquement", "deployee" et "recette en lab".
- Ne pas affirmer l'exclusivite d'une image Vulhub : seules les 12 failles du scenario sont intentionnelles et recettees.
- Ne pas dupliquer de flags ni de secrets reutilisables hors lab.
- Ajouter captures, commandes executees et resultats observes apres recette.
