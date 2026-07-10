# Infrastructure

> Certains guides et scripts associés à ce projet sont en cours de remise à jour.  
> Merci de vérifier les versions utilisées (OS, paquets, application) avant de les utiliser en production.

Ce dossier regroupe les éléments liés à la conception, à l’organisation et à la sécurisation de l’environnement technique sur lequel reposaient les différents projets menés pendant mon alternance.

Il complète le dossier `projets/` en documentant non plus les services eux-mêmes, mais la base technique nécessaire à leur déploiement, à leurs tests et à leur maintien dans le temps.

## Objectif du dossier

L’objectif de ce dossier est de présenter les composants structurants de l’infrastructure mise en place, ainsi que les choix techniques qui ont permis d’héberger et de sécuriser les différents services.

Il permet de donner une vue plus globale de l’environnement, en montrant que les projets présentés dans ce dépôt s’inscrivent dans une architecture cohérente et non dans une succession d’installations isolées.

## Sujets abordés

Ce dossier peut regrouper, selon les besoins :

- la segmentation réseau ;
- le plan d’adressage ;
- les VLANs ;
- le routage inter-VLAN ;
- les règles de filtrage et de pare-feu ;
- la virtualisation avec Proxmox ;
- le reverse proxy ;
- les certificats SSL/TLS ;
- l’accès distant sécurisé via VPN ;
- les éléments de supervision et d’observabilité ;
- les schémas ou documents d’architecture.

## Logique de documentation

Les contenus rassemblés ici sont issus d’un contexte réel de mise en place d’infrastructure, mais sont reformulés pour rester lisibles et réutilisables.

Selon les dossiers, certaines documentations peuvent décrire un environnement de test, des choix d’architecture, des procédures de configuration ou des points de vigilance à prendre en compte avant une mise en production.

## Lien avec les projets

L’infrastructure constitue la base sur laquelle reposent les services présentés dans le dossier `projets/`.

Sans segmentation réseau, virtualisation, accès sécurisés, reverse proxy, certificats et supervision, les services déployés n’auraient pas pu être testés, sécurisés et maintenus dans de bonnes conditions.