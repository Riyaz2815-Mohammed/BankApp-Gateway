local jwt  = require "resty.jwt"
local http = require "resty.http"
local cjson = require "cjson.safe"

local SKIP_AUTH = {
    ["/api/v1/health"] = true,
    ["/api/v1/info"]   = true,
}

local REALM_URL = os.getenv("KEYCLOAK_REALM_URL") or "http://keycloak:8080/realms/bankapp"

local function json_err(status, message)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        status    = status,
        message   = message,
        data      = cjson.null,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }))
    return ngx.exit(status)
end

local function fetch_public_key()
    local httpc = http.new()
    httpc:set_timeout(5000)
    local res, err = httpc:request_uri(REALM_URL, {
        method  = "GET",
        headers = { Accept = "application/json" },
    })
    if not res or res.status ~= 200 then
        return nil, "keycloak unreachable: " .. (err or tostring(res and res.status or "?"))
    end
    local body, decode_err = cjson.decode(res.body)
    if not body or not body.public_key then
        return nil, "no public_key in realm response: " .. (decode_err or "")
    end
    return "-----BEGIN PUBLIC KEY-----\n" .. body.public_key .. "\n-----END PUBLIC KEY-----"
end

local function get_public_key()
    local cache = ngx.shared.jwks_cache
    local pem = cache:get("pem")
    if pem then return pem end
    local new_pem, err = fetch_public_key()
    if not new_pem then return nil, err end
    cache:set("pem", new_pem, 3600)
    return new_pem
end

if SKIP_AUTH[ngx.var.uri] then return end

local auth_header = ngx.var.http_authorization
if not auth_header then
    return json_err(401, "Missing Authorization header")
end
local token = auth_header:match("^Bearer%s+(.+)$")
if not token then
    return json_err(401, "Invalid Authorization header format")
end

local pem, key_err = get_public_key()
if not pem then
    ngx.log(ngx.ERR, "jwt_verify: failed to get public key: ", key_err)
    return json_err(502, "Authentication service unavailable")
end

local verified = jwt:verify(pem, token)
if not verified.verified then
    ngx.log(ngx.WARN, "jwt_verify: ", verified.reason)
    return json_err(401, verified.reason or "Invalid or expired token")
end

local payload = verified.payload
ngx.req.set_header("X-User-Sub",   payload.sub   or "")
ngx.req.set_header("X-User-Email", payload.email or "")
if payload.realm_access and payload.realm_access.roles then
    ngx.req.set_header("X-User-Roles", table.concat(payload.realm_access.roles, ","))
end
