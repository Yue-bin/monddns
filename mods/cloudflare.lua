--[[
    cloudflare的ddns相关的部分api
    设计上一个实例关联一个token或者email+api_key
    具体的zone_id在运行时维护
--]]
local _M = {}

local url = require("socket.url")
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local dnsrecord = require("mods.dnsrecord")


local base_url = "https://api.cloudflare.com/client/v4"
local req_headers = {
    ["Content-Type"] = "application/json",
}
local log = nil

-- 在log前面加上模块名
local function cf_log(msg, level)
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    log:log("<cloudflare> " .. msg, level)
end

-- 统一处理cf的返回
local function cf_request(reqt)
    local resp_body = {}
    reqt.headers = req_headers
    reqt.sink = ltn12.sink.table(resp_body)
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    if log.LOG_LEVEL == "TRACE" then
        local reqt_dump = {}
        for k, v in pairs(reqt) do
            if k == "source" then
                local result = {}
                local sink = ltn12.sink.table(result)
                -- 使用 ltn12.pump.all 从 source 提取数据到 result
                local success, err = ltn12.pump.all(v, sink)
                if not success then
                    cf_log("Failed to extract data from source: " .. tostring(err), "TRACE")
                end
                reqt_dump.source = table.concat(result)
                -- 重建source
                reqt.source = ltn12.source.string(reqt_dump.source)
            elseif k == "sink" then
                reqt_dump[k] = "sink"
            else
                reqt_dump[k] = v
            end
        end
        cf_log("request: " .. json.encode(reqt_dump), "TRACE")
    end
    local _, code, headers, status = http.request(reqt)
    -- 判断状态码是否为2xx
    if code >= 200 and code < 300 then
        cf_log("request success with code " .. code .. ", body " .. table.concat(resp_body), "TRACE")
        return json.decode(table.concat(resp_body))
    else
        if next(resp_body) then
            cf_log("request failed with code " .. code .. ", body " .. table.concat(resp_body), "TRACE")
            return nil, code, table.concat(resp_body)
        end
        cf_log("request failed with code " .. code, "TRACE")
        return nil, code, ""
    end
end

-- 将dnsrecord类型转换为cloudflare的record类型
local function dnsrecord_to_cfrecord(dr, comment, is_proxied)
    local cf_dr = {
        comment = comment or "",
        content = dr.value,
        name = dr.rr .. "." .. dr.domain,
        proxied = is_proxied or false,
        ttl = dr.ttl,
        type = dr.type,
    }
    return cf_dr
end

-- 将cloudflare的record类型转换为dnsrecord类型
local function cfrecord_to_dnsrecord(cf_dr)
    local dr = dnsrecord.new_dnsrecord {
        id = cf_dr.id,
        rr = string.gsub(cf_dr.name, "." .. cf_dr.zone_name, ""),
        domain = cf_dr.zone_name,
        type = cf_dr.type,
        value = cf_dr.content,
        ttl = cf_dr.ttl }
    return dr
end

-- 获取zone_id
function _M.get_zone_id(domain_name)
    local resp_body, code, err = cf_request({
        -- /zones
        url = base_url .. "/zones?name=" .. url.escape(domain_name),
        method = "GET"
    })
    if not resp_body or not resp_body.result[1] then
        return nil, code, err
    else
        cf_log("get zone id: " .. resp_body.result[1].id .. " of " .. domain_name, "INFO")
        return resp_body.result[1].id
    end
end

-- 获取dns记录
function _M.get_dns_records(rr, domain, zone_id, match_opt)
    match_opt = match_opt or "exact"
    local resp_body, code, err = cf_request({
        -- /zones/{zone_id}/dns_records
        url = base_url ..
            "/zones/" .. zone_id .. "/dns_records?name%2e" .. url.escape(match_opt) .. "=" .. url.escape(rr ..
                "." .. domain),
        method = "GET"
    })
    if not resp_body then
        return nil, code, err
    else
        -- 将结果归一化为recordlist类型
        local result = dnsrecord.new_recordlist()
        for _, v in ipairs(resp_body.result) do
            result = result .. cfrecord_to_dnsrecord(v)
        end
        return result
    end
end

-- 删除dns记录
function _M.delete_dns_record(recordlist, zone_id)
    for _, dr in ipairs(recordlist) do
        -- /zones/{zone_id}/dns_records/{dns_record_id}
        local result, code, err = cf_request {
            url = base_url .. "/zones/" .. zone_id .. "/dns_records/" .. dr.id,
            method = "DELETE"
        }
        if result then
            cf_log("delete dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " success", "INFO")
        else
            cf_log(
                "delete dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " failed: " .. code .. " " .. err,
                "ERROR")
        end
    end
end

-- 创建dns记录
function _M.create_dns_record(recordlist, zone_id)
    for _, dr in ipairs(recordlist) do
        -- /zones/{zone_id}/dns_records
        local result, code, err = cf_request {
            url = base_url .. "/zones/" .. zone_id .. "/dns_records",
            method = "POST",
            source = ltn12.source.string(json.encode(dnsrecord_to_cfrecord(dr)))
        }
        if result then
            cf_log("create dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " success", "INFO")
        else
            cf_log(
                "create dns record " .. dr.value .. " " .. dr.rr ..
                "." .. dr.domain .. " failed: " .. code .. " " .. err,
                "ERROR")
        end
    end
end

function _M.new(init_info)
    if not init_info.auth then
        return nil, "missing auth"
    end
    if init_info.auth.api_token then
        req_headers["Authorization"] = "Bearer " .. init_info.auth.api_token
    elseif init_info.auth.email and init_info.auth.api_key then
        req_headers["X-Auth-Email"] = init_info.auth.email
        req_headers["X-Auth-Key"] = init_info.auth.api_key
    else
        return nil, "invalid auth type"
    end
    log = init_info.log or require("mods.log").init()
    return _M
end

return _M
