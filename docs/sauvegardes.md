# Stratégie de sauvegarde

Objectif : pouvoir tout reconstruire après une erreur, un disque mort ou un vol, sans
payer de stockage pour ce qui se régénère.

## Trois niveaux

| Niveau | Où | Protège contre |
|---|---|---|
| Exports applicatifs | disque de données de la VM (`/srv/data/backups`) | suppression, corruption, mise à jour ratée |
| Copie locale | disque de sauvegarde de l'hôte (SSD USB) | perte de la VM ou de son disque |
| Hors site | dépôt restic chiffré (cloud ou machine distante) | vol, incendie, perte du serveur entier |

## Déroulé de la nuit

| Heure | Où | Quoi | Rétention |
|---|---|---|---|
| 03:00 | hôte | configuration de l'hôte (`/etc`, dont `/etc/pve`, et les scripts) | 7 copies |
| 03:15 | VM | export de la base Nextcloud, rejeté s'il est tronqué | 7 copies |
| 03:22 | VM | export complet Paperless (miroir incrémental) | miroir |
| 03:25 | VM | archive du coffre Vaultwarden | 14 copies |
| 03:30 | hôte | `vzdump` : système de la VM et des conteneurs, **sans** le disque de données | 3 quotidiennes + 2 hebdomadaires |
| 03:40 | VM | coffre Vaultwarden hors site | 7 j, 4 sem., 6 mois |
| 04:00 | hôte | l'hôte **tire** les fichiers utiles de la VM (rsync) | miroir |
| dim. 05:00 | VM | exports + fichiers Nextcloud hors site | 7 j, 4 sem., 6 mois |

Chaque ligne envoie un signal à healthchecks.io : un échec **ou un silence** déclenche
une alerte (voir [surveillance.md](surveillance.md)).

## Choix et raisons

- **Exports applicatifs plutôt que copie des fichiers de base.** Copier les fichiers
  d'une base MariaDB ou SQLite en marche donne une copie incohérente. Chaque service
  a donc son export natif : `mariadb-dump --single-transaction`, `vaultwarden backup`,
  `document_exporter` de Paperless (réimportable même dans une version plus récente).
- **Un export incomplet ne remplace jamais une bonne copie.** L'export est écrit en
  `.tmp`, vérifié (marqueur de fin du dump), puis renommé. Sinon, rotation après
  rotation, les bonnes copies disparaissent.
- **Le disque de données est exclu du `vzdump`.** Un `vzdump` relit tout le disque
  chaque nuit, photos et médias compris. Il ne garde que le système de la VM ; les
  données utiles sont choisies une par une et copiées en fichiers (quelques centaines
  de Mo au lieu de centaines de Go). Restaurer = restaurer la VM, recréer le disque de
  données, recopier les fichiers.
- **L'hôte tire, la VM ne pousse pas.** La VM, exposée sur internet, n'a aucun accès à
  l'hôte ni au disque de sauvegarde : une VM compromise ne peut pas effacer ses
  sauvegardes. La clé SSH de l'hôte est restreinte à son adresse (`from=`).
- **Hors site chiffré côté client.** restic chiffre avant l'envoi : le fournisseur de
  stockage ne voit rien. Le mot de passe du dépôt est gardé **hors du serveur** (sans
  lui, la copie hors site est inutile).
- **Le coffre de mots de passe part hors site chaque nuit**, le reste chaque semaine :
  c'est le plus critique et il pèse quelques Ko.
- **Garde-fou de taille** sur l'envoi hors site : une erreur (un dossier de vidéos
  déposé dans Nextcloud) ne doit pas remplir le quota ni saturer la connexion.
- **Ce qui n'est pas sauvegardé, et c'est voulu** : miniatures (régénérables), journaux,
  caches. Pour les photos, tant qu'il n'y a pas de place hors site, les téléphones
  restent la seconde copie : c'est écrit, pas découvert le jour de la panne.

## Restauration testée

Une sauvegarde qui n'a jamais été restaurée est une hypothèse. Le `vzdump` a été
restauré dans une VM de test **non démarrée** (pour ne pas créer un doublon sur le
réseau), puis le contenu vérifié (données, configuration Nextcloud, exports), puis la
VM de test supprimée. À refaire après chaque changement de la stratégie.

Pour le dépôt hors site, un `restic check --read-data-subset 5%` de temps en temps
relit une partie des données réellement envoyées.

## Pièges rencontrés

- **`vzdump` ignore une exclusion qui finit par `/`** (`/opt/cache/`) : le job finit en
  « WARNINGS: 1 » et le dossier est sauvegardé quand même. Écrire `/opt/cache/?*`
  (garde le dossier, exclut son contenu).
- **Le crochet d'un job `vzdump` doit toujours sortir en 0**, sinon c'est la
  sauvegarde elle-même qui échoue ([`vzdump-signal.sh`](../scripts/vzdump-signal.sh)).
- **restic regroupe les instantanés par chemin** : sauvegarder une archive horodatée
  crée un groupe par jour et la rétention ne s'applique jamais. D'où la copie à chemin
  fixe `dernier.tar.gz`.
- **L'identifiant partagé de rclone pour Google Drive est limité par Google**
  (`RATE_LIMIT_EXCEEDED`) : 56 Mo ont mis plus de 20 minutes. Créer son propre
  identifiant d'API, ou viser une machine amie en `sftp:` par un VPN.
