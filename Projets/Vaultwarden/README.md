# Vaultwarden – Gestionnaire de mots de passe auto‑hébergé

> Certains guides et scripts associés à ce projet sont en cours de remise à jour.  
> Merci de vérifier les versions utilisées (OS, paquets, application) avant de les utiliser en production.
## Résumé
Vaultwarden est une solution de gestion de mots de passe auto‑hébergée, mise en place dans le cadre de mon alternance en Administratrice d’Infrastructures Sécurisées (AIS) chez Konexio.

Ce projet répondait au besoin de remplacer un document Google partagé contenant des identifiants sensibles par une solution centralisée, sécurisée et structurée.

La solution s’intègre dans une infrastructure segmentée (Admin / Front / Test / Prod) et peut être réutilisée dans d’autres contextes associatifs ou professionnels.


## Contexte et besoin
Avant ce projet, les mots de passe partagés entre équipes étaient stockés dans un document collaboratif en ligne (Google Docs), sans chiffrement ni contrôle fin des accès.

Cela posait des problèmes de sécurité (exposition des identifiants), de traçabilité et de gestion des droits par utilisateur ou par équipe.

Le besoin identifié était :

- Centraliser les mots de passe dans un coffre sécurisé.
- Limiter l’accès aux bonnes personnes (équipes, rôles).
- Améliorer les pratiques de sécurité sans complexifier le quotidien des utilisateurs.


## Choix de la solution
Plusieurs solutions de gestion de mots de passe ont été étudiées avant de retenir Vaultwarden.

Les critères principaux étaient :

- Solution open source et auto‑hébergeable (contexte associatif avec budget limité).
- Chiffrement des données et compatibilité avec l’écosystème Bitwarden.
- Intégration possible dans l’infrastructure existante (VM Proxmox, reverse proxy, VPN, VLAN dédiés).

Vaultwarden a été retenu car il répondait à ces critères, tout en restant léger et simple à déployer dans un environnement virtualisé.

## Architecture technique
Vaultwarden est déployé sur une machine virtuelle Linux hébergée sur un cluster Proxmox dans une zone réseau dédiée (Test, puis Prod prévue).

- L’infrastructure globale est segmentée en plusieurs zones (Admin, Front, Test, Prod, VM Test/Prod) avec des VLAN et un plan d’adressage IP structuré.
- L’accès à Vaultwarden se fait via un reverse proxy (par exemple Apache), qui :
- Terminate le HTTPS (certificat) pour sécuriser les connexions.
- Évite l’exposition directe du service Vaultwarden sur Internet.

Ce positionnement permet de tester le service en environnement isolé avant un passage en production, tout en respectant les contraintes de sécurité du contexte associatif.

## Installation et déploiement
L’installation de Vaultwarden s’appuie sur :

- Une VM Linux (Debian/Ubuntu) avec accès administrateur.
- La mise en place du service Vaultwarden (via binaire ou conteneur, selon le scénario retenu).
- La configuration de l’URL, du stockage des données et de l’intégration avec le reverse proxy.
- Des scripts Bash ont été développés pour automatiser les étapes d’installation et de configuration afin de rendre le déploiement reproductible.

Ces scripts seront publiés et remis à jour dans ce dépôt, avec une attention particulière aux versions actuelles des paquets (OS, Vaultwarden, dépendances).

## Sécurité et bonnes pratiques
Plusieurs mesures ont été intégrées dans le projet pour renforcer la sécurité :

- Politique de mot de passe principal
- Mot de passe fort (minimum 12 caractères, majuscules, minuscules, chiffres, caractères spéciaux).
- Authentification
- Activation recommandée de l’authentification à deux facteurs (2FA) pour les comptes utilisateurs.
- Gestion des accès
- Utilisation d’organisations et de collections pour séparer les identifiants selon les profils (administration, collaborateurs, formateurs, apprenants).
- Contrôle des inscriptions
- Inscription uniquement sur invitation, aucune création de compte en libre accès.

Ces choix permettent d’améliorer nettement la sécurité par rapport à l’ancien système basé sur un document partagé.

## Accompagnement des utilisateurs
Pour faciliter l’adoption du service, plusieurs supports ont été réalisés :

- Un guide utilisateur détaillant :
- L’inscription via lien d’invitation.
- La première connexion.
- La découverte de l’interface (coffre personnel, coffres d’organisation).
- L’ajout d’éléments (mots de passe, notes sécurisées, envois via la fonctionnalité Send).
- Une documentation technique / administrateur (gestion des organisations, collections, invitations, paramètres de sécurité).
- Des supports visuels (vidéos) pour les personnes moins à l’aise avec les guides texte.
Les documents seront référencés dans ce dépôt (au format Markdown et/ou PDF) avec une mention claire de leur statut de mise à jour.

## Résultats, limites et statut actuel
### Résultats obtenus :

- Vaultwarden fonctionnel en environnement de test, avec intégration dans l’infrastructure segmentée de Konexio.
- Documentation utilisateur et technique prête pour un déploiement plus large.
- Scripts et architecture réutilisables dans d’autres contextes (association, formation, entreprise).

### Limites :

Le projet a été interrompu pour des raisons organisationnelles et financières, indépendantes de la qualité technique du déploiement.

L’infrastructure initiale ayant été démontée, Vaultwarden n’est plus en production actuellement.

### Statut dans ce dépôt :

Le projet est présenté comme un cas complet de mise en place d’un gestionnaire de mots de passe auto‑hébergé, avec une mise à jour prévue des scripts et des guides en fonction des versions actuelles.