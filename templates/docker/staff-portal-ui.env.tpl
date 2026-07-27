HOSTNAME="0.0.0.0"
PORT=3000
NODE_ENV=production

# Browser + server both use host-published IAM (container needs extra_hosts localhost→host-gateway).
IAM_URL="http://localhost:{{IAM_STAFF_PORT}}"
LOGIN_PROVIDER_ID="1"
