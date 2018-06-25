-- lua_shared_dict ip_blacklist 1m;

local redis_server = "127.0.0.1"
local redis_port = 6379
local redis_key = "ip_blacklist"
local redis_connection_timeout = 1000
local cache_ttl = 60

local ip = nginx.var.remote_addr  -- the client ip，will be judged in shared_ip_blacklist
local last_update_time = ip_blacklist:get("last_update_time");

if last_update_time == nil or last_update_time <( ngx.now()-cache_ttl) then
    local redis = require "resty.redis"
    local red = redis:new();

    red:set_timeout(redis_connection_timeout)   -- 1s
    local ok,err = red:connect(redis_server,redis_port);
    if not ok then
        ngx.log(ngx.DEBUG,"Redis connection error while retrieving ip_blacklist:"..err)
    else
        local new_ip_blacklist,err = red:smembers(redis_key);
        if err then
            ngx.log(ngx.DEBUG,"Redis read error whilr retrieving ip_blacklist:"..err);
        else
            ip_blacklist:flush_all();
            for index,banned_ip in ipairs(new_ip_blacklist) do
                ip_blacklist:set(banned_ip,true);
            end

            -- update last_update_time
            ip_blacklist:set("last_update_time",ngx.now());
        end
    end
end

if ip_blacklist:get(ip) then   
    -- the client ip belongs to the ip_blacklist
    ngx.log(ngx.Debug,"Banned IP detected and refused access:"..ip);
    return ngx.exit(ngx.HTTP_FORBIDDEN);
end
