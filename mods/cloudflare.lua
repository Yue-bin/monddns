--[[
    cloudflare的ddns相关的部分api
    设计上一个实例关联一个token或者email+api_key
    具体的zone_id在运行时维护
--]]
local _M = {}
local base = _G

local url = base.require("socket.url")
local http = base.require("socket.http")
local ltn12 = base.require("ltn12")
local json = base.require("cjson")
local dnsrecord = base.require("mods.dnsrecord")


local base_url = "https://api.cloudflare.com/client/v4"
local req_headers = {
    ["Content-Type"] = "application/json",
}

-- 统一处理cf的返回
local function cf_request(reqt)
    local resp_body = {}
    reqt.headers = req_headers
    reqt.sink = ltn12.sink.table(resp_body)
    local _, code, headers, status = http.request(reqt)
    -- 判断状态码是否为2xx
    if code >= 200 and code < 300 then
        return json.decode(resp_body[1]), code
    else
        if resp_body then
            return nil, code, json.decode(resp_body[1])
        end
        return nil, code
    end
end

--[[
    curl --request GET \
    --url 'https://api.cloudflare.com/client/v4/zones?name=example.com'
]]
-- 获取zone_id
function _M.get_zone_id(domain_name)
    local resp_body, code, err = cf_request({
        url = base_url .. "/zones?name=" .. domain_name,
        method = "GET"
    })
    if not resp_body then
        return nil, code, err
    else
        return resp_body.result[1].id
    end
end

--[=[
curl --request GET \
                    --url 'https://api.cloudflare.com/client/v4/zones/CFZoneID/dns_records?comment=CfComment' \
                    --header 'Content-Type: application/json' \
                    --header 'Authorization: Bearer ]] .. CFAPIKey
--]=]
-- 获取dns记录
function _M.get_dns_records(name, zone_id, match_opt)
    match_opt = match_opt or "exact"
    local resp_body, code, err = cf_request({
        url = base_url .. "/zones/" .. zone_id .. "/dns_records?name." .. match_opt .. "=" .. name,
        method = "GET"
    })
    if not resp_body then
        return nil, code, err
    else
        -- 将结果归一化为recordlist类型
        local result = dnsrecord.new_recordlist()
        for _, v in ipairs(resp_body.result) do
            local dr = dnsrecord.new_dnsrecord(
                base.string.gsub(v.name, "." .. v.zone_name, ""),
                v.zone_name,
                v.type,
                v.content,
                v.ttl)
            result = result + dr
        end
        print(result)
        return result
    end
end

-- 更新dns记录
function _M.update_dns_record(dns_record, zone_id)
end

-- 删除dns记录
function _M.delete_dns_record(dns_record, zone_id)
end

-- 创建dns记录
function _M.create_dns_record(dns_record, zone_id)
end

function _M.new(auth)
    if not auth then
        return nil, "missing auth"
    elseif auth.api_token then
        req_headers["Authorization"] = "Bearer " .. auth.api_token
    elseif auth.email and auth.api_key then
        req_headers["X-Auth-Email"] = auth.email
        req_headers["X-Auth-Key"] = auth.api_key
    else
        return nil, "invalid auth type"
    end
    return _M
end

return _M
