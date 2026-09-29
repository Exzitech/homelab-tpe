# Surveillance et alertes

Principe : **l'alerte ne doit pas dépendre de la machine surveillée.** Un serveur
éteint ou coupé du réseau ne peut envoyer aucune alerte ; c'est donc un service
extérieur (healthchecks.io, gratuit jusqu'à 20 contrôles, ou une instance
auto-hébergée ailleurs) qui attend des signaux et alerte **quand ils manquent**.
Les alertes arrivent par e-mail et sur le téléphone (ntfy).

## Trois scripts

- [`avec-signal.sh`](../scripts/avec-signal.sh) enrobe n'importe quelle tâche cron :
  signal de début, puis code de sortie et fin du journal. Healthchecks affiche la durée
  de chaque tâche et le journal de l'échec dans la notification. Sans clé ni internet,
  la tâche tourne quand même.
- [`vzdump-signal.sh`](../scripts/vzdump-signal.sh) fait de même pour le job de
  sauvegarde Proxmox, dont il est le crochet, et liste les machines en échec.
- [`surveillance.sh`](../scripts/surveillance.sh) tourne sur l'hôte toutes les 5
  minutes et vérifie :
  - VM et conteneurs démarrés ;
  - services publics joignables **par leur nom de domaine**, comme un utilisateur ;
  - certificats **servis** valides encore au moins 14 jours (un renouvellement
    « réussi » sur le disque ne prouve pas que le proxy le sert) ;
  - disques (hôte, thin pool LVM, disque de sauvegarde monté, VM, conteneurs) sous 90 % ;
  - DNS local qui répond ;
  - message de blocage de la carte réseau dans le journal du noyau
    ([incident](incident-carte-reseau.md)).

  Rien à signaler : signal « OK ». Sinon : signal d'échec avec la liste des problèmes.

## Réglages des contrôles

| Contrôle | Période | Grâce |
|---|---|---|
| surveillance (`serveur`) | 5 min | 10 min |
| sauvegardes quotidiennes | 1 jour | 2 h (3 h pour le `vzdump`) |
| hors site hebdomadaire | 7 jours | 6 h |

## Pièges rencontrés

- **cron n'a pas `/usr/sbin` dans son `PATH`** : `qm`, `pct` et `lvs` y sont
  introuvables, donc la première exécution a signalé toutes les machines arrêtées.
  Le script fixe son `PATH`, et **une mesure vide compte comme un problème**, jamais
  comme un disque vide.
- **Un contrôle qui n'a jamais reçu de signal reste « new » et n'alerte pas.** Après
  la mise en place, vérifier que chaque contrôle est passé au moins une fois « up ».
