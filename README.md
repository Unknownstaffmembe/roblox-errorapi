A pretty badly designed/made and simple error reporting api backend.

# Dependencies
lua-http: https://github.com/daurnimator/lua-http

lua-cjson: https://luarocks.org/modules/openresty/lua-cjson

luasql-sqlite3: https://luarocks.org/modules/tomasguisasola/luasql-sqlite3

# Recommendations
Use luajit for maximum performance.

Run this behind a reverse proxy (e.g. Nginx) since this doesn't use https and, it doesn't have a rate limiter built in.

# Note
default authorization key = `NotASecureKey` which has an **access level** of `255`.
