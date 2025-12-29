#!/bin/bash

# Script pour générer et uploader les certificats SSL/TLS vers Azure Key Vault
# Usage: ./scripts/manage-certificates.sh [dev|prod] [create|delete|verify]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEV_DOMAIN="dev.lesaiglesbraves.online"
PROD_DOMAIN="prod.lesaiglesbraves.online"
DEV_KEYVAULT="owncloudkvdev"
PROD_KEYVAULT="owncloudkvprod"

# Fonction pour afficher les messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    info "Vérification des prérequis..."
    
    if ! command -v az &> /dev/null; then
        error "Azure CLI n'est pas installé. Installez-le depuis: https://docs.microsoft.com/cli/azure/install-azure-cli"
    fi
    
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL n'est pas installé. Installez-le avec: apt-get install openssl"
    fi
    
    # Vérifier la connexion Azure
    if ! az account show &> /dev/null; then
        error "Vous n'êtes pas connecté à Azure. Exécutez: az login"
    fi
    
    info "✓ Tous les prérequis sont satisfaits"
}

# Fonction pour générer les certificats auto-signés
generate_certificates() {
    local domain=$1
    local cert_dir="./certs"
    
    info "Génération des certificats pour le domaine: $domain"
    
    # Créer le répertoire pour les certificats
    mkdir -p "$cert_dir"
    
    # Générer le certificat Keycloak
    info "Génération du certificat Keycloak..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/keycloak-tls-key.pem" \
        -out "$cert_dir/keycloak-tls-cert.pem" \
        -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$domain" \
        -addext "subjectAltName=DNS:$domain,DNS:*.$domain" 2>/dev/null
    
    # Générer le certificat OCIS
    info "Génération du certificat OCIS..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/ocis-tls-key.pem" \
        -out "$cert_dir/ocis-tls-cert.pem" \
        -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$domain" \
        -addext "subjectAltName=DNS:$domain,DNS:*.$domain" 2>/dev/null
    
    info "✓ Certificats générés avec succès dans $cert_dir"
}

# Fonction pour uploader les certificats vers Azure Key Vault
upload_certificates() {
    local keyvault=$1
    local cert_dir="./certs"
    
    info "Upload des certificats vers Key Vault: $keyvault"
    
    # Upload Keycloak certificate
    info "Upload du certificat Keycloak..."
    az keyvault certificate import \
        --vault-name "$keyvault" \
        --name keycloak-tls-cert \
        --file "$cert_dir/keycloak-tls-cert.pem" \
        > /dev/null
    
    az keyvault secret set \
        --vault-name "$keyvault" \
        --name keycloak-tls-key \
        --file "$cert_dir/keycloak-tls-key.pem" \
        --content-type "application/x-pem-file" \
        > /dev/null
    
    # Upload OCIS certificate
    info "Upload du certificat OCIS..."
    az keyvault certificate import \
        --vault-name "$keyvault" \
        --name ocis-tls-cert \
        --file "$cert_dir/ocis-tls-cert.pem" \
        > /dev/null
    
    az keyvault secret set \
        --vault-name "$keyvault" \
        --name ocis-tls-key \
        --file "$cert_dir/ocis-tls-key.pem" \
        --content-type "application/x-pem-file" \
        > /dev/null
    
    info "✓ Certificats uploadés avec succès"
    
    # Nettoyer les fichiers temporaires
    rm -rf "$cert_dir"
    info "✓ Fichiers temporaires nettoyés"
}

# Fonction pour supprimer les certificats d'Azure Key Vault
delete_certificates() {
    local keyvault=$1
    
    warn "Suppression des certificats du Key Vault: $keyvault"
    
    # Supprimer les certificats Keycloak
    az keyvault certificate delete \
        --vault-name "$keyvault" \
        --name keycloak-tls-cert \
        > /dev/null 2>&1 || true
    
    az keyvault secret delete \
        --vault-name "$keyvault" \
        --name keycloak-tls-key \
        > /dev/null 2>&1 || true
    
    # Supprimer les certificats OCIS
    az keyvault certificate delete \
        --vault-name "$keyvault" \
        --name ocis-tls-cert \
        > /dev/null 2>&1 || true
    
    az keyvault secret delete \
        --vault-name "$keyvault" \
        --name ocis-tls-key \
        > /dev/null 2>&1 || true
    
    info "✓ Certificats supprimés"
}

# Fonction pour vérifier les certificats dans Azure Key Vault
verify_certificates() {
    local keyvault=$1
    
    info "Vérification des certificats dans Key Vault: $keyvault"
    
    echo ""
    echo "=== Certificats ==="
    az keyvault certificate list \
        --vault-name "$keyvault" \
        --query "[?starts_with(name, 'keycloak-tls') || starts_with(name, 'ocis-tls')].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}" \
        --output table
    
    echo ""
    echo "=== Secrets (Clés privées) ==="
    az keyvault secret list \
        --vault-name "$keyvault" \
        --query "[?starts_with(name, 'keycloak-tls') || starts_with(name, 'ocis-tls')].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}" \
        --output table
}

# Fonction principale
main() {
    local environment=$1
    local action=$2
    
    # Vérifier les arguments
    if [ -z "$environment" ] || [ -z "$action" ]; then
        echo "Usage: $0 [dev|prod] [create|delete|verify]"
        echo ""
        echo "Actions:"
        echo "  create  - Générer et uploader de nouveaux certificats"
        echo "  delete  - Supprimer les certificats existants"
        echo "  verify  - Vérifier les certificats dans Key Vault"
        exit 1
    fi
    
    # Définir les variables selon l'environnement
    local domain
    local keyvault
    
    case $environment in
        dev)
            domain=$DEV_DOMAIN
            keyvault=$DEV_KEYVAULT
            ;;
        prod)
            domain=$PROD_DOMAIN
            keyvault=$PROD_KEYVAULT
            ;;
        *)
            error "Environnement invalide: $environment. Utilisez 'dev' ou 'prod'."
            ;;
    esac
    
    info "Environnement: $environment"
    info "Domaine: $domain"
    info "Key Vault: $keyvault"
    echo ""
    
    # Vérifier les prérequis
    check_prerequisites
    
    # Exécuter l'action demandée
    case $action in
        create)
            generate_certificates "$domain"
            upload_certificates "$keyvault"
            verify_certificates "$keyvault"
            info "✓ Création des certificats terminée avec succès!"
            ;;
        delete)
            read -p "Êtes-vous sûr de vouloir supprimer les certificats? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                delete_certificates "$keyvault"
                info "✓ Suppression des certificats terminée"
            else
                info "Opération annulée"
            fi
            ;;
        verify)
            verify_certificates "$keyvault"
            ;;
        *)
            error "Action invalide: $action. Utilisez 'create', 'delete' ou 'verify'."
            ;;
    esac
}

# Exécuter le script
main "$@"
