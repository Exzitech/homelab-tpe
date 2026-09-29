# Incident : serveur allumé mais injoignable après un gros import

## Ce qui s'est passé

Pendant l'import d'environ 13 000 photos vers le serveur, l'hôte Proxmox est devenu
injoignable : plus d'interface web, plus aucun service. La machine était pourtant
allumée. Seul un redémarrage physique l'a fait revenir.

## Diagnostic

Le journal du noyau de la session précédente (`journalctl -k -b -1`) montrait, en
boucle pendant l'import :

```
e1000e ... nic0: Detected Hardware Unit Hang
```

La carte réseau intégrée (Intel, pilote `e1000e`) se bloquait sous forte charge.
C'est un problème connu de ce pilote sur plusieurs générations de puces : les
**déchargements matériels** (la carte découpe et regroupe elle-même les paquets TCP
à la place du processeur) finissent par bloquer la file d'émission quand le débit
reste élevé longtemps.

## Correctif

Désactiver ces déchargements. Le processeur reprend ce travail ; à l'échelle d'un
lien gigabit domestique, le coût est négligeable.

```sh
ethtool -K nic0 tso off gso off gro off
```

Une commande `ethtool` est perdue au redémarrage. Pour la rendre permanente, une
ligne `post-up` sous l'interface physique dans `/etc/network/interfaces` (après en
avoir gardé une copie) :

```
iface nic0 inet manual
        post-up /usr/sbin/ethtool -K nic0 tso off gso off gro off
```

## Vérification

- Redémarrage de l'hôte, puis `ethtool -k nic0 | grep -E 'segmentation|receive-offload'` :
  les trois déchargements sont à `off`, et tous les services sont remontés seuls.
- **Détection ajoutée à la surveillance** : [`surveillance.sh`](../scripts/surveillance.sh)
  cherche ce message dans le journal du noyau toutes les 5 minutes et alerte même si
  le lien est revenu entre-temps. Si la carte bloque au point de couper le réseau,
  c'est l'absence de signal qui alerte (voir [surveillance.md](surveillance.md)).

## Si ça revient

1. Désactiver aussi les sommes de contrôle matérielles (`ethtool -K nic0 rx off tx off`).
2. Sinon, remplacer la carte intégrée par une carte PCIe ou USB d'une autre famille.
3. En attendant, pour un gros import : éviter la fenêtre des sauvegardes nocturnes
   et limiter le parallélisme de l'envoi.

## Ce que j'en retiens

- « Allumé mais injoignable » oriente vers le réseau avant le disque ou la mémoire :
  lire le journal du noyau de la session **précédente**, pas de la session courante.
- Un correctif n'est terminé qu'une fois **vérifié après redémarrage** : la plupart
  des réglages réseau appliqués à la main disparaissent au prochain démarrage.
- Chaque incident doit laisser une détection derrière lui.
