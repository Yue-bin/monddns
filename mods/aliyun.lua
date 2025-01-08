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
local hmac = base.require("openssl.hmac")
local dnsrecord = base.require("mods.dnsrecord")

local log = nil
local req_headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
}

local function build_query_string(query_param)
    local parts = {}
    for k, v in pairs(query_param) do
        table.insert(parts, k .. "=" .. v)
    end
    return table.concat(parts, "&")
end

local function tohex(b)
    local x = ""
    for i = 1, #b do
        x = x .. string.format("%.2x", string.byte(b, i))
    end
    return x
end

-- 阿里签名相关，此处仅实现v2 rpc风格 post方法 的签名(我查过元数据了我需要的几个方法都支持get和post)
local ak_id = ""
local ak_secret = ""

-- 一些固定值
local procto = "https://"
local endpoint = "dns.aliyuncs.com"
local http_method = "POST"
local api_ver = "2015-01-09"
local format = "JSON"
local sign_method = "HMAC-SHA1"
local sign_ver = "1.0"

-- 生成公共请求参数
-- 带sign的时候生成sign键，用于最终请求，不带时不生成，用于签名
local function gen_pub_params(action, sign)
    local pub_params = {
        AccessKeyId = ak_id,
        Format = format,
        SignatureMethod = sign_method,
        SignatureVersion = sign_ver,
        Timestamp = base.os.date("!%Y-%m-%dT%H:%M:%SZ"),
        Version = api_ver,
    }
    if sign then
        pub_params.Signature = sign
    end
    return pub_params
end

-- 生成签名
local function gen_signature(params)
    local keys = {}
    -- 插入自定义参数
    for k, _ in pairs(params) do
        base.table.insert(keys, k)
    end
    -- 插入公共请求参数(不含signature)
    for k, _ in pairs(params) do
        base.table.insert(keys, k)
    end
    base.table.sort(keys)
    local canonicalized_query_string = {}
    for _, k in pairs(keys) do
        table.insert(canonicalized_query_string, url.escape(k) .. "=" .. url.escape(params[k]))
    end
    local string_to_sign = http_method ..
        "&" .. url.escape("/") .. "&" .. url.escape(table.concat(canonicalized_query_string, "&"))
    local key = ak_secret .. "&"
    local hmac_sha1 = hmac.new(key, "sha1"):final()
end

-- 统一处理ali的返回
local function ali_request(reqt)
    local sign = gen_signature(reqt)
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

ali_request({})

function _M.new(init_info)
    if not init_info.auth then
        return nil, "missing auth"
    elseif init_info.auth.ak_id and init_info.auth.ak_secret then
        ak_id = init_info.auth.ak_id
        ak_secret = init_info.auth.ak_secret
    else
        return nil, "invalid auth type"
    end
    log = init_info.log or require("mods.log").init()
    return _M
end

return _M
