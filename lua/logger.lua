local cjson = require "cjson.safe"

local uri = ngx.var.request_uri or ""
local req_type
if     uri:sub(1, 10) == "/api/auth/" then req_type = "nextauth"
elseif uri:sub(1,  5) == "/api/"      then req_type = "api"
elseif uri:sub(1,  6) == "/auth/"     then req_type = "oidc"
else                                        req_type = "frontend"
end

local upstream_ms_raw = ngx.var.upstream_response_time
local upstream_ms = nil
if upstream_ms_raw and upstream_ms_raw ~= "" and upstream_ms_raw ~= "-" then
    upstream_ms = math.floor(tonumber(upstream_ms_raw) * 1000)
end

local upstream_status = ngx.var.upstream_status
if upstream_status == "" then upstream_status = nil end

local log = {
    type            = req_type,
    time            = ngx.var.time_iso8601,
    request_id      = ngx.var.request_id,
    method          = ngx.var.request_method,
    host            = ngx.var.host,
    path            = ngx.var.request_uri,
    protocol        = ngx.var.server_protocol,
    status          = ngx.status,
    upstream        = ngx.var.upstream_addr or "none",
    upstream_status = upstream_status,
    duration_ms     = math.floor(tonumber(ngx.var.request_time) * 1000),
    upstream_ms     = upstream_ms,
    request_bytes   = tonumber(ngx.var.request_length),
    response_bytes  = tonumber(ngx.var.body_bytes_sent),
    client_ip       = ngx.var.remote_addr,
    forwarded_for   = ngx.var.http_x_forwarded_for,
    ssl_protocol    = ngx.var.ssl_protocol,
    ssl_cipher      = ngx.var.ssl_cipher,
    user_agent      = ngx.var.http_user_agent,
    referer         = ngx.var.http_referer,
    user_sub        = ngx.var.http_x_user_sub,
    user_email      = ngx.var.http_x_user_email,
    user_roles      = ngx.var.http_x_user_roles,
}

ngx.log(ngx.NOTICE, "[" .. req_type .. "] " .. (cjson.encode(log) or "{}"))
