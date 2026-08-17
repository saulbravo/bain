#!/bin/sh
cd /app/imba
export API_URL=http://127.0.0.1:8000
export HOST=127.0.0.1
export PORT=3000
exec npx pm2-runtime server.mjs
