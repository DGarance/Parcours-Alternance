#!/bin/bash

#=============================================
# Script d'installation de GLPI
# Auteur : Garance Defrel
# Version : 4.0 — testé sur Ubuntu 24.04 et 26.04
#=============================================

LOG_FILE="/var/log/glpi-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Vérification root
if [ "$EUID" -ne 0 ]; then
    echo "[ERREUR] Ce script doit être exécuté avec sudo ou en tant que root."
    exit 1
fi

# Variables — valeurs par défaut modifiables ci-dessous ou via variables d'environnement
DB_NAME="${GLPI_DB_NAME:-glpi_db}"
DB_USER="${GLPI_DB_USER:-glpi_user}"
GLPI_DOMAIN="${GLPI_DOMAIN:-glpi.local}"
TMP_DIR="/tmp"

# Mot de passe MySQL : jamais en dur dans le script.
# S'il n'est pas défini via GLPI_DB_PASS, on le demande à l'exécution.
if [ -z "$GLPI_DB_PASS" ]; then
    read -s -p "Mot de passe MySQL pour $DB_USER : " GLPI_DB_PASS
    echo
fi
MYSQL_PASS="$GLPI_DB_PASS"

echo "[INFO] Configuration automatique de l'installation de GLPI"
echo "[INFO] Domaine GLPI : $GLPI_DOMAIN"

# =============================================
# ÉTAPES 1-5 : INSTALLATION FONCTIONNELLE
# Suffisantes pour un usage local/test.
# =============================================

# Fonction : Mise à jour du système et installation des dépendances
function update_system(){
    echo "[INFO] Mise à jour du système..."
    if apt update && apt upgrade -y; then
        echo "[OK] Système à jour"
    else
        echo "[ERREUR] Echec de la mise à jour."
        exit 1
    fi
    echo "[INFO] Installation des dépendances..."
    if apt-get install -y apache2 mariadb-server php php-{xml,curl,gd,intl,mysql,bcmath,mbstring,bz2,zip,ldap}; then
        echo "[OK] Dépendances installées."
    else
        echo "[ERREUR] Echec de l'installation des paquets."
        exit 1
    fi
}

# Fonction : Sécurisation de MariaDB
function secure_mariaDB(){
    echo "[INFO] Sécurisation de MariaDB..."
    if mysql_secure_installation <<EOF
Y
Y
$MYSQL_PASS
$MYSQL_PASS
Y
Y
Y
Y
EOF
    then
        echo "[OK] MariaDB sécurisée."
    else
        echo "[ERREUR] La sécurisation de MariaDB a échoué."
        exit 1
    fi
}

# Fonction : Configuration de la base de données
function config_database(){
    echo "[INFO] Création et configuration de la base de données..."
    if mysql -u root -p"$MYSQL_PASS" -e "
        CREATE DATABASE IF NOT EXISTS $DB_NAME;
        CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
        GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
        FLUSH PRIVILEGES;"; then
        echo "[OK] Base de données configurée"
    else
        echo "[ERREUR] Erreur lors de la configuration de la base de données."
        exit 1
    fi
}

# Fonction : Installation de GLPI
function install_glpi(){
    echo "[INFO] Téléchargement de GLPI..."
    GLPI_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)
    GLPI_URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"

    cd "$TMP_DIR" || exit 1

    if wget -q "$GLPI_URL" -O glpi.tgz && tar -xzf glpi.tgz; then
        echo "[OK] Téléchargement et extraction réussis."
    else
        echo "[ERREUR] Échec lors du téléchargement ou de l'extraction."
        exit 1
    fi

    GLPI_DIR=$(tar -tzf glpi.tgz | head -1 | cut -d"/" -f1)
    mv "$GLPI_DIR" /var/www/glpi
    chown -R www-data:www-data /var/www/glpi

    echo "[OK] GLPI installé dans /var/www/glpi."
}

# Fonction : Configuration Apache (VirtualHost minimal)
function config_apache(){
    echo "[INFO] Configuration d'Apache..."
    VHOST="/etc/apache2/sites-available/$GLPI_DOMAIN.conf"

    cat << EOF > "$VHOST"
<VirtualHost *:80>
    ServerName $GLPI_DOMAIN
    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF

    if a2enmod rewrite && a2ensite "$GLPI_DOMAIN" && a2dissite 000-default.conf && systemctl reload apache2; then
        echo "[OK] VirtualHost Apache configuré."
    else
        echo "[ERREUR] Erreur lors de la configuration d'apache."
        exit 1
    fi
}

# Installation fonctionnelle complète (étapes 1 à 5)
function install_minimal(){
    update_system
    secure_mariaDB
    config_database
    install_glpi
    config_apache
    echo "[INFO] Installation fonctionnelle terminée."
    echo "[INFO] Finalisez maintenant via l'interface web : http://$GLPI_DOMAIN"
}

# =============================================
# ÉTAPES 6-7 : SÉCURISATION RECOMMANDÉE (PRODUCTION)
# Non requises pour que GLPI fonctionne. Isolent les
# fichiers sensibles du DocumentRoot public et protègent
# les cookies de session contre le vol via JavaScript (XSS).
# =============================================

# Fonction : Isolation des fichiers sensibles hors du DocumentRoot
function secure_folders(){
    echo "[INFO] Isolation des fichiers sensibles (config, données, logs)..."

    mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
    cp -r /var/www/glpi/config /etc/glpi
    cp -r /var/www/glpi/files/* /var/lib/glpi/

    chown -R www-data:www-data /var/www/glpi /etc/glpi /var/lib/glpi /var/log/glpi
    chmod -R 750 /etc/glpi /var/lib/glpi /var/log/glpi

    echo "<?php define('GLPI_CONFIG_DIR', '/etc/glpi/'); if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) require_once GLPI_CONFIG_DIR . '/local_define.php'; ?>" > /var/www/glpi/inc/downstream.php
    echo "<?php define('GLPI_VAR_DIR', '/var/lib/glpi'); define('GLPI_LOG_DIR', '/var/log/glpi'); ?>" > /etc/glpi/local_define.php

    echo "[OK] Fichiers sensibles isolés."
}

# Fonction : Sécurisation PHP (protection cookies de session)
function secure_php(){
    echo "[INFO] Sécurisation PHP..."
    PHP_INI="/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/php.ini"
    if [ -f "$PHP_INI" ]; then
        sed -i 's/^;*session.cookie_httponly.*/session.cookie_httponly = On/' "$PHP_INI"
        systemctl reload apache2
        echo "[OK] session.cookie_httponly activé."
    else
        echo "[ERREUR] Fichier php.ini introuvable."
        exit 1
    fi
}

# Installation + sécurisation production (étapes 1 à 7)
function install_production(){
    install_minimal
    secure_folders
    secure_php
    echo "[INFO] Installation + sécurisation production terminée."
    echo "[INFO] Finalisez maintenant via l'interface web : http://$GLPI_DOMAIN"
}

# =============================================
# MISE À JOUR
# =============================================

function update_glpi(){
    echo "[INFO] Mise à jour de GLPI..."

    DATE_NOW=$(date +%Y%m%d%H%M%S)
    BACKUP_DIR="/var/backups/glpi/$DATE_NOW"
    GLPI_ROOT="/var/www/glpi"

    if [ ! -d "$GLPI_ROOT" ] || [ ! -f "$GLPI_ROOT/index.php" ]; then
        echo "[ERREUR] GLPI n'est pas installé (ou installation invalide) dans $GLPI_ROOT"
        return 1
    fi

    mkdir -p "$BACKUP_DIR"

    echo "[INFO] Sauvegarde de la base de données..."
    mysqldump -u "$DB_USER" -p"$MYSQL_PASS" "$DB_NAME" > "$BACKUP_DIR/glpi_db_backup_$DATE_NOW.sql" \
        && echo "[OK] Base sauvegardée." || { echo "[ERREUR] Échec sauvegarde DB."; return 1; }

    [ -d "/etc/glpi" ] && cp -r /etc/glpi "$BACKUP_DIR/glpi_config_backup_$DATE_NOW"
    [ -d "/var/lib/glpi" ] && cp -r /var/lib/glpi "$BACKUP_DIR/files_backup_$DATE_NOW"
    [ -d "$GLPI_ROOT/marketplace" ] && cp -r "$GLPI_ROOT/marketplace" "$BACKUP_DIR/marketplace_backup_$DATE_NOW"
    [ -d "$GLPI_ROOT/plugins" ] && cp -r "$GLPI_ROOT/plugins" "$BACKUP_DIR/plugins_backup_$DATE_NOW"

    systemctl stop apache2

    cd "$TMP_DIR" || exit 1
    GLPI_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)
    GLPI_URL="https://github.com/glpi-project/glpi/releases/download/$GLPI_VERSION/glpi-$GLPI_VERSION.tgz"

    rm -f glpi_update.tgz
    rm -rf glpi/

    wget -q "$GLPI_URL" -O glpi_update.tgz || { echo "[ERREUR] Échec téléchargement."; systemctl start apache2; return 1; }
    tar -tzf glpi_update.tgz >/dev/null 2>&1 || { echo "[ERREUR] Archive corrompue."; systemctl start apache2; return 1; }
    tar -xzf glpi_update.tgz || { echo "[ERREUR] Échec extraction."; systemctl start apache2; return 1; }

    mv "$GLPI_ROOT" "$BACKUP_DIR/glpi_old_$DATE_NOW"

    GLPI_DIR=$(find . -maxdepth 1 -type d -name "glpi*" | head -1)
    if [ -z "$GLPI_DIR" ]; then
        echo "[ERREUR] Répertoire GLPI non trouvé après extraction."
        mv "$BACKUP_DIR/glpi_old_$DATE_NOW" "$GLPI_ROOT"
        systemctl start apache2
        return 1
    fi
    mv "$GLPI_DIR" /var/www/glpi

    [ -d "$BACKUP_DIR/config_backup_$DATE_NOW" ] && cp -r "$BACKUP_DIR/config_backup_$DATE_NOW"/* /etc/glpi/ 2>/dev/null
    if [ -d "$BACKUP_DIR/files_backup_$DATE_NOW" ]; then
        rm -rf /var/lib/glpi/*
        cp -r "$BACKUP_DIR/files_backup_$DATE_NOW"/* /var/lib/glpi/
    fi
    [ -d "$BACKUP_DIR/marketplace_backup_$DATE_NOW" ] && cp -r "$BACKUP_DIR/marketplace_backup_$DATE_NOW" "$GLPI_ROOT/marketplace"
    [ -d "$BACKUP_DIR/plugins_backup_$DATE_NOW" ] && cp -r "$BACKUP_DIR/plugins_backup_$DATE_NOW" "$GLPI_ROOT/plugins"

    chown -R www-data:www-data /var/www/glpi /etc/glpi /var/lib/glpi /var/log/glpi
    chmod -R 750 /etc/glpi /var/lib/glpi /var/log/glpi

    systemctl start apache2
    systemctl is-active --quiet apache2 && echo "[OK] Apache redémarré." || echo "[WARN] Problème redémarrage Apache."

    cd /var/www/glpi || return 1
    sudo -u www-data php bin/console db:update --no-interaction 2>/dev/null \
        && echo "[OK] Mise à jour DB terminée." \
        || echo "[WARN] Finalisez via l'interface web : http://$GLPI_DOMAIN"

    rm -f "$TMP_DIR/glpi_update.tgz"
    echo "[OK] ===== MISE À JOUR DE GLPI TERMINÉE ====="
    echo "[INFO] Version installée : $GLPI_VERSION"
    echo "[INFO] Sauvegardes disponibles dans : $BACKUP_DIR"
}

# Menu interactif
function interactive_menu() {
    while true; do
        echo
        echo "========================================="
        echo " Installation GLPI"
        echo "========================================="
        read -n1 -p "[a] Installation minimale (fonctionnelle), [b] Installation + sécurisation production, [1-7] étape individuelle, [u] Mise à jour, [q] Quitter : " choice
        echo
        case $choice in
            [aA]) install_minimal ;;
            [bB]) install_production ;;
            1) update_system ;;
            2) secure_mariaDB ;;
            3) config_database ;;
            4) install_glpi ;;
            5) config_apache ;;
            6) secure_folders ;;
            7) secure_php ;;
            [uU]) update_glpi ;;
            [qQ]) echo "Fin du script." ; break ;;
            *) echo "[ERREUR] Option invalide." ;;
        esac
    done
}

# Lancement
case "$1" in
    --auto) install_minimal ;;
    --auto-prod) install_production ;;
    *) interactive_menu ;;
esac