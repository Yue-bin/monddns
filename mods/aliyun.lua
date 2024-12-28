---@diagnostic disable: need-check-nil
--[[
    aliyun的ddns相关的部分api
    设计上一个实例关联一个ak和ak secret

    此模块尚未开始编写
--]]
local _M = {}
local base = _G

local url = base.require("socket.url")
local http = base.require("socket.http")
local ltn12 = base.require("ltn12")
local json = base.require("cjson")
local dnsrecord = base.require("mods.dnsrecord")



local log = nil

-- 统一处理ali的返回
local function ali_request(reqt)
    local resp_body = {}
    reqt.headers = req_headers
    reqt.sink = ltn12.sink.table(resp_body)
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    if log.LOG_LEVEL == "DEBUG" then
        local reqt_dump = {}
        for k, v in base.pairs(reqt) do
            if k == "source" then
                local result = {}
                local sink = ltn12.sink.table(result)
                -- 使用 ltn12.pump.all 从 source 提取数据到 result
                local success, err = ltn12.pump.all(v, sink)
                if not success then
                    ali_log("Failed to extract data from source: " .. base.tostring(err), "DEBUG")
                end
                reqt_dump.source = base.table.concat(result)
                -- 重建source
                reqt.source = ltn12.source.string(reqt_dump.source)
            elseif k == "sink" then
                reqt_dump[k] = "sink"
            else
                reqt_dump[k] = v
            end
        end
        ali_log("request: " .. json.encode(reqt_dump), "DEBUG")
    end
    local _, code, headers, status = http.request(reqt)
    -- 判断状态码是否为2xx
    if code >= 200 and code < 300 then
        ali_log("request success with code " .. code .. ", body " .. resp_body[1], "DEBUG")
        return json.decode(resp_body[1]), code
    else
        if resp_body then
            ali_log("request failed with code " .. code .. ", body " .. resp_body[1], "DEBUG")
            return nil, code, json.decode(resp_body[1])
        end
        ali_log("request failed with code " .. code, "DEBUG")
        return nil, code
    end
end

-- 将dnsrecord类型转换为cloudflare的record类型
local function dnsrecord_to_alirecord(dr, comment, is_proxied)
    local ali_dr = {
        comment = comment or "",
        content = dr.value,
        name = dr.rr .. "." .. dr.domain,
        proxied = is_proxied or false,
        ttl = dr.ttl,
        type = dr.type,
    }
    return ali_dr
end

-- 将cloudflare的record类型转换为dnsrecord类型
local function alirecord_to_dnsrecord(ali_dr)
    local dr = dnsrecord.new_dnsrecord {
        id = ali_dr.id,
        rr = base.string.gsub(ali_dr.name, "." .. ali_dr.zone_name, ""),
        domain = ali_dr.zone_name,
        type = ali_dr.type,
        value = ali_dr.content,
        ttl = ali_dr.ttl }
    return dr
end

function _M.new(init_info)
    if not init_info.auth then
        return nil, "missing auth"
    elseif init_info.auth.api_token then
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
