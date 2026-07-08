#!/bin/bash
# LearnForge Admin Setter
#
# Verwendung:
#   ./scripts/set-admin.sh <deine-email>
#
# Beispiel:
#   ./scripts/set-admin.sh greenman999@example.com
#
# Das Skript findet den api-Container und setzt die angegebene Email
# auf admin + grantet free (dauerhafter Zugriff ohne Abo).

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Fehler: Bitte gib deine Email an."
  echo "Verwendung: $0 <email>"
  exit 1
fi

EMAIL="$1"

# Api-Container finden
CONTAINER=$(docker ps --filter "name=learnforge.*api" --format "{{.Names}}" | head -1)
if [ -z "$CONTAINER" ]; then
  CONTAINER=$(docker ps --filter "name=api" --format "{{.Names}}" | head -1)
fi

if [ -z "$CONTAINER" ]; then
  echo "Fehler: Kein laufender api-Container gefunden."
  echo "Verfügbare Container:"
  docker ps --format "table {{.Names}}\t{{.Image}}"
  exit 1
fi

echo "Container gefunden: $CONTAINER"
echo "Setze Email '$EMAIL' auf admin..."
echo ""

# Schritt 1: User-ID finden und auf admin setzen
RESULT=$(docker exec -i "$CONTAINER" psql -U learnforge -d learnforge -t -c "
  UPDATE users
  SET role = 'admin'
  WHERE email = '$EMAIL'
  RETURNING id, email, role;
" 2>&1)

echo "$RESULT"

# Prüfen ob erfolgreich
ID=$(echo "$RESULT" | head -1 | xargs)
if [ -z "$ID" ]; then
  echo ""
  echo "FEHLER: Kein User mit der Email '$EMAIL' gefunden."
  echo "Hast du dich schon registriert?"
  exit 1
fi

# Schritt 2: Free granten
echo ""
echo "Grantiere dauerhaften Free-Zugriff..."
docker exec -i "$CONTAINER" psql -U learnforge -d learnforge -c "
  UPDATE users
  SET subscription_status = 'free',
      stripe_subscription_id = NULL,
      subscription_current_period_end = NULL,
      trial_ends_at = '2099-12-31 23:59:59+00'
  WHERE email = '$EMAIL';
" 2>&1

echo ""
echo "Fertig! Du bist jetzt Admin mit dauerhaftem Zugriff."
echo "Der Admin-Bereich ist unter Dashboard -> Einstellungen erreichbar."
echo ""
echo "Tipp: Setze danach REGISTRATIONS_DISABLED=true in Dokploy."
