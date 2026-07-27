PORT=3000
# Server-side Next.js fetches (inside the UI container) — use Compose DNS, not host localhost.
BACKEND_API_URL="http://{{REGISTRY_STAFF_API_SERVICE}}:8000"
MASTERDATA_BACKEND_API_URL="http://{{REGISTRY_MASTER_DATA_API_SERVICE}}:8000"
DEFAULT_LOCALE="en"
PARTNER_IMPORT_EXPORT_ENABLE="true"
PAGE_SIZE=10

# Browser logout redirect + server-side IAM calls. Requires extra_hosts localhost→host-gateway.
IAM_URL="http://localhost:{{IAM_STAFF_PORT}}"
KEYCLOAK_LOGOUT_URL="{{KEYCLOAK_URL}}/realms/staff/protocol/openid-connect/logout"
LOGIN_PROVIDER_ID="1"
APPLICATION_MNEMONIC="{{REGISTRY_UI_APP_MNEMONIC}}"
COOKIE_DOMAIN="localhost"
REDIRECT_URL="http://localhost:{{REGISTRY_UI_PORT}}"
