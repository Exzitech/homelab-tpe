# Paperless-ngx alimenté par Nextcloud

Besoin : numériser un courrier avec le téléphone ou déposer une facture depuis le PC,
et la retrouver classée, avec son texte cherchable, sans application de plus.

## Fonctionnement

1. Chaque personne a un dossier « A classer » dans son Nextcloud, synchronisé sur ses
   appareils.
2. Ce dossier est monté dans le dossier d'entrée de Paperless
   ([compose](../services/paperless/docker-compose.yml)).
3. Paperless avale le fichier (OCR, classement), puis le supprime du dossier.
4. Un rescan ciblé toutes les 5 minutes ([`nextcloud-rescan.sh`](../scripts/nextcloud-rescan.sh),
   ~1 s) retire le fichier de l'index de Nextcloud.

Avec plusieurs dossiers (un par personne, un commun), un **workflow Paperless** par
dossier (déclencheur « Consumption Started », filtre de chemin `*/consume/<dossier>/*`)
attribue le propriétaire du document.

## Détails qui comptent

- **Même utilisateur que Nextcloud.** Paperless tourne en uid 33 (`www-data`), sinon
  il ne peut pas supprimer les fichiers déposés par Nextcloud et les avale en boucle.
  Changer ensuite le propriétaire de ses dossiers (`chown 33:33`).
- **Fichiers en cours d'envoi ignorés.** Nextcloud écrit d'abord un
  `nom.ocTransferIdNNN.part` : Paperless doit l'ignorer, sinon il avale un fichier
  à moitié reçu.
- **Nextcloud ne voit pas ce qui change sous lui.** Sans le rescan, les documents
  avalés restent affichés et les clients de synchronisation tentent de les récupérer.
- **SQLite plutôt que PostgreSQL** : pour quelques comptes, un conteneur et ~100 Mo
  de RAM en moins, sans différence perceptible.
- **Ressources bornées** : 1 document à la fois, 2 pages en parallèle, 2 Go de RAM
  maximum. L'OCR d'un gros PDF ne ralentit pas les autres services de la VM.
- **Sauvegarde par l'export officiel** (`document_exporter`), pas par copie des
  fichiers : originaux, versions OCR et base en JSON, réimportables dans une version
  plus récente.
- **Supprimer un document en ligne de commande** : `Document.delete()` le met à la
  corbeille, et une purge par l'ORM laisse les fichiers sur le disque. Passer par la
  corbeille de l'interface, ou vérifier ensuite avec `document_sanity_checker`.
