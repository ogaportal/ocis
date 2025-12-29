#!/bin/bash
set -e

# Configuration
ADMIN_USER="admin"
ADMIN_PASS="$1"
CLIENT_SECRET="$2"
REDIRECT_URL="$3"
WEB_ORIGIN="$4"

echo "=== Keycloak Configuration Script ==="
echo "Redirect URL: $REDIRECT_URL"
echo "Web Origin: $WEB_ORIGIN"

# Login
echo "Step 1: Login to Keycloak..."
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS"

# Create realm
echo "Step 2: Creating realm 'owncloud'..."
/opt/keycloak/bin/kcadm.sh create realms -s realm=owncloud -s enabled=true -s displayName='ownCloud' -s registrationAllowed=true -s registrationEmailAsUsername=true -s rememberMe=true -s verifyEmail=false -s loginWithEmailAllowed=true -s duplicateEmailsAllowed=false -s resetPasswordAllowed=true -s editUsernameAllowed=false -o 2>/dev/null || echo 'Realm already exists'

# Create client
echo "Step 3: Creating OIDC client 'ocis'..."
/opt/keycloak/bin/kcadm.sh create clients -r owncloud -s clientId=ocis -s enabled=true -s clientAuthenticatorType=client-secret -s secret="$CLIENT_SECRET" -s publicClient=false -s protocol=openid-connect -s standardFlowEnabled=true -s implicitFlowEnabled=false -s directAccessGrantsEnabled=true -s serviceAccountsEnabled=false -s "redirectUris=[\"$REDIRECT_URL\"]" -s "webOrigins=[\"$WEB_ORIGIN\"]" -s baseUrl="$WEB_ORIGIN" -s fullScopeAllowed=true -o 2>/dev/null || echo 'Client already exists'

# Create test user
echo "Step 4: Creating test user..."
/opt/keycloak/bin/kcadm.sh create users -r owncloud -s username=testuser -s email=test@lesaiglesbraves.online -s firstName=Test -s lastName=User -s enabled=true -s emailVerified=true -o 2>/dev/null || echo 'User already exists'

# Set password
echo "Step 5: Setting password for test user..."
USER_ID=$(/opt/keycloak/bin/kcadm.sh get users -r owncloud -q username=testuser --fields id --format csv --noquotes)
if [ ! -z "$USER_ID" ]; then
  /opt/keycloak/bin/kcadm.sh set-password -r owncloud --username testuser --new-password 'Test@123'
  echo 'Password set successfully!'
else
  echo 'User not found'
fi

echo "=== Configuration completed! ==="
