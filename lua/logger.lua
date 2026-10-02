local cjson = require "cjson.safe"

local log = {
    time        = ngx.var.time_iso8601,
    method      = ngx.var.request_method,
    path        = ngx.var.request_uri,
    status      = ngx.status,
    duration_ms = math.floor(tonumber(ngx.var.request_time) * 1000),
    upstream    = ngx.var.upstream_addr or "none",
    bytes_sent  = tonumber(ngx.var.body_bytes_sent),
    client_ip   = ngx.var.remote_addr,
}

ngx.log(ngx.NOTICE, "[api] " .. (cjson.encode(log) or "{}"))
