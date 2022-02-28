A pretty badly designed/made and simple error reporting api backend.

# Dependencies
lua-http: https://github.com/daurnimator/lua-http
lua-cjson: https://luarocks.org/modules/openresty/lua-cjson
luasql-sqlite3: https://luarocks.org/modules/tomasguisasola/luasql-sqlite3

# Recommendations
I recommend using LuaJIT for better performance (rather than using Lua 5.1, 5.2, 5.3, etc)
I also recommend running this behind a reverse proxy (e.g. Nginx) since this doesn't use https and, it doesn't have a rate limiter built in.

