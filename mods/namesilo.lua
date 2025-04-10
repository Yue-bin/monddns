--[[
    namesilo的ddns相关的部分api
    设计上一个实例关联一个apikey

    此模块尚未经过实际测试
--]]
local _M = {}

local http = require("socket.http")
local json = require("cjson")
local dnsrecord = require("dnsrecord")


local base_url = "https://www.namesilo.com/api/"
local base_query_param = {
    version = 1,
    type = "json",
}
local log = nil

-- 构造查询字符串
local function build_query_string(query_param)
    local parts = {}
    for k, v in pairs(base_query_param) do
        table.insert(parts, k .. "=" .. v)
    end
    for k, v in pairs(query_param) do
        table.insert(parts, k .. "=" .. v)
    end
    return table.concat(parts, "&")
end

-- 在log前面加上模块名
local function ns_log(msg, level)
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    log:log("<namesilo> " .. msg, level)
end

-- 统一构造ns的请求并处理返回
local function ns_request(opration, query_param)
    query_param = query_param or {}
    local req_url = base_url .. opration .. "?" .. build_query_string(query_param)
    ns_log("request url: " .. req_url, "DEBUG")
    local resp_body, code, headers, status = http.request(req_url)
    -- 判断http状态码是否为2xx, 以及返回的body里的code是否为3xx
    if code >= 200 and code < 300 then
        ns_log("request success with code " .. code .. ", body " .. resp_body, "TRACE")
        if resp_body and json.decode(resp_body) and tonumber(json.decode(resp_body).reply.code) >= 300 and tonumber(json.decode(resp_body).reply.code) < 400 then
            return json.decode(resp_body)
        end
        return nil, code, json.decode(resp_body)
    else
        if resp_body then
            ns_log("request failed with code " .. code .. ", body " .. resp_body, "TRACE")
            return nil, code, resp_body
        end
        ns_log("request failed with code " .. code, "TRACE")
        return nil, code, ""
    end
end

-- 注意ns的record类型发送请求时的字段名不一样，所以不能进行二次转换
-- 将dnsrecord类型转换为namesilo的发送record类型
local function dnsrecord_to_nsrecord(dr, comment, is_proxied)
    local ns_dr = {
        domain = dr.domain,
        rrtype = dr.type,
        rrhost = dr.rr,
        rrvalue = dr.value,
        rrttl = dr.ttl,
    }
    return ns_dr
end

-- 将接收到的namesilo的record类型转换为dnsrecord类型
local function nsrecord_to_dnsrecord(ns_dr)
    local dr = dnsrecord.new_dnsrecord {
        id = ns_dr.record_id,
        rr = string.match(ns_dr.host, "(.+)%.[^%.]+%.[^%.]+$"),
        domain = string.match(ns_dr.host, "[^%.]+%.[^%.]+$"),
        type = ns_dr.type,
        value = ns_dr.value,
        ttl = ns_dr.ttl,
    }
    return dr
end

-- 获取zone_id
function _M.get_zone_id(_)
    return "none"
end

-- 获取dns记录
function _M.get_dns_records(rr, domain, zone_id)
    local resp_body, code, err = ns_request("dnsListRecords", { domain = domain })
    if not resp_body then
        return nil, code, err
    else
        -- 将结果归一化为recordlist类型
        local result = dnsrecord.new_recordlist()
        for _, v in ipairs(resp_body.reply.resource_record) do
            if v.host == rr .. domain then
                result = result .. nsrecord_to_dnsrecord(v)
            end
        end
        return result
    end
end

-- 删除dns记录
function _M.delete_dns_record(recordlist, zone_id)
    for _, dr in ipairs(recordlist) do
        local result, code, err = ns_request("dnsDeleteRecord", { domain = dr.domain, rrid = dr.id })
        if result then
            ns_log("delete dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " success", "INFO")
        else
            ns_log(
                "delete dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " failed: " .. code .. " " .. err,
                "ERROR")
        end
    end
end

-- 创建dns记录
function _M.create_dns_record(recordlist, zone_id)
    for _, dr in ipairs(recordlist) do
        local result, code, err = ns_request(
            "dnsAddRecord",
            dnsrecord_to_nsrecord(dr))
        if result then
            ns_log("create dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " success", "INFO")
        else
            ns_log(
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
    if init_info.auth.apikey then
        base_query_param.key = init_info.auth.apikey
    else
        return nil, "invalid auth type"
    end
    log = init_info.log or require("mods.log").init()
    return _M
end

return _M
