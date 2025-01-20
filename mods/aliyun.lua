--[[
    aliyun的ddns相关的部分api
    设计上一个实例关联一个ak和ak secret

    此模块尚未开始编写
--]]
local _M = {}

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local hmac = require("openssl.hmac")
local dnsrecord = require("mods.dnsrecord")
local basexx = require("basexx")

local log = nil
local req_headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
}

-- 在log前面加上模块名
local function ali_log(msg, level)
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    log:log("<aliyun> " .. msg, level)
end

-- 拜阿里所赐，我需要实现一个使用大写字母十六进制编码的urlencode
local function url_encode(input)
    -- 保留不需要编码的字符
    local safe_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"

    local function encode_char(char)
        local byte = string.byte(char)
        -- 对 ASCII 范围字符进行处理
        if safe_chars:find(char, 1, true) then
            return char
        elseif byte == 32 then -- 空格转为%20
            return "%20"
        else
            -- 非安全字符用%加16进制表示
            return string.format("%%%02X", byte):upper()
        end
    end

    -- 调整匹配模式，兼容 Lua 5.1
    return string.gsub(input, "[^%w%-%.%_%~ ]", function(char)
        return encode_char(char)
    end):gsub(" ", "%%20") -- 替换空格为%20
end

-- encode不为nil则进行urlencode
local function build_query_string(query_param, encode)
    local urlencode = function(tmp)
        return tmp
    end
    if encode then
        urlencode = url_encode
    end
    local parts = {}
    for k, v in pairs(query_param) do
        table.insert(parts, urlencode(k) .. "=" .. urlencode(v))
    end
    return table.concat(parts, "&")
end

local function build_query_string_ordered(query_param, encode)
    local urlencode = function(tmp)
        return tmp
    end
    if encode then
        urlencode = url_encode
    end
    local parts = {}
    for _, param in pairs(query_param) do
        table.insert(parts, urlencode(param.key) .. "=" .. urlencode(param.value))
    end
    return table.concat(parts, "&")
end

-- 阿里签名相关，此处仅实现v2 rpc风格 post方法 的签名(我查过元数据了我需要的几个方法都支持get和post)
local ak_id = ""
local ak_secret = ""

-- 一些固定值
local _PROTO = "https://"
local _ENDPOINT = "dns.aliyuncs.com"
local _HTTP_METHOD = "POST"
local _API_VER = "2015-01-09"
local _FORMAT = "JSON"
local _SIGN_METHOD = "HMAC-SHA1"
local _SIGN_VER = "1.0"

math.randomseed(os.time())

-- 生成公共请求参数
-- 不包含signature，需要在生成签名之后加入
local function gen_pub_params(action)
    -- 防止一秒内签出两个nonce一样的签名
    local pub_params = {
        Action = action,
        Version = _API_VER,
        Format = _FORMAT,
        AccessKeyId = ak_id,
        SignatureNonce = tostring(math.random(1000000000, 9999999999)),
        Timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        SignatureMethod = _SIGN_METHOD,
        SignatureVersion = _SIGN_VER,
    }
    return pub_params
end

-- 把表转换成有序的形式
local function to_ordered(params)
    local ordered = {}
    for k, v in pairs(params) do
        table.insert(ordered, { key = k, value = v })
    end
    table.sort(ordered, function(a, b)
        return a.key < b.key
    end)
    return ordered
end

-- 生成签名
local function gen_signature(params)
    local ordered_params = to_ordered(params)
    local canonicalized_query_string = build_query_string_ordered(ordered_params, true)
    local string_to_sign = _HTTP_METHOD .. "&" .. url_encode("/") .. "&" .. url_encode(canonicalized_query_string)
    ali_log("string to sign: " .. string_to_sign, "DEBUG")
    local sign = basexx.to_base64(hmac.new(ak_secret .. "&", "sha1"):final(string_to_sign))
    return sign
end

-- 统一处理ali的返回
local function ali_request(action, params)
    local pub_params = gen_pub_params(action)
    local full_params = {}
    for k, v in pairs(pub_params) do
        full_params[k] = v
    end
    for k, v in pairs(params) do
        full_params[k] = v
    end
    local sign = gen_signature(full_params)
    local reqt_url = _PROTO ..
        _ENDPOINT .. "/?" .. build_query_string(pub_params, true) .. "&Signature=" .. url_encode(sign)
    local resp_body = {}
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    if log.LOG_LEVEL == "DEBUG" then
        ali_log("request: " .. reqt_url, "DEBUG")
        ali_log("request params: " .. json.encode(params), "DEBUG")
    end
    local _, code, headers, status = http.request {
        url = reqt_url,
        method = _HTTP_METHOD,
        headers = req_headers,
        sink = ltn12.sink.table(resp_body),
        source = ltn12.source.string(build_query_string(params, true)),
    }
    -- 判断状态码是否为2xx
    if code >= 200 and code < 300 then
        ali_log("request success with code " .. code .. ", body " .. table.concat(resp_body), "DEBUG")
        return json.decode(table.concat(resp_body)), code
    else
        if next(resp_body) then
            ali_log("request failed with code " .. code .. ", body " .. table.concat(resp_body), "DEBUG")
            return nil, code, table.concat(resp_body)
        end
        ali_log("request failed with code " .. code, "DEBUG")
        return nil, code
    end
end

-- 将dnsrecord类型转换为cloudflare的record类型
local function dnsrecord_to_alirecord(dr, comment, is_proxied)
    local ali_dr = {
        Value = dr.value,
        RR = dr.rr,
        DomainName = dr.domain,
        TTL = dr.ttl == 1 and 600 or dr.ttl,
        Type = dr.type,
    }
    return ali_dr
end

-- 将cloudflare的record类型转换为dnsrecord类型
local function alirecord_to_dnsrecord(ali_dr)
    local dr = dnsrecord.new_dnsrecord {
        id = ali_dr.RecordId,
        rr = ali_dr.RR,
        domain = ali_dr.DomainName,
        type = ali_dr.Type,
        value = ali_dr.Value,
        ttl = ali_dr.ttl }
    return dr
end

function _M.get_zone_id(_)
    return "none"
end

function _M.get_dns_records(rr, domain, zone_id, match_opt)
    match_opt = match_opt or "exact"
    match_opt = match_opt:upper()
    local resp_body, code, err = ali_request("DescribeDomainRecords", {
        DomainName = domain,
        KeyWord = rr,
        SearchMode = match_opt,
        Status = "ENABLE",
    })
    if not resp_body or not resp_body.DomainRecords then
        return nil, code, err
    else
        local result = dnsrecord.new_recordlist()
        for _, record in ipairs(resp_body.DomainRecords.Record) do
            result = result .. alirecord_to_dnsrecord(record)
        end
        return result
    end
end

function _M.delete_dns_record(recordlist, zone_id)
    for _, dr in ipairs(recordlist) do
        -- /zones/{zone_id}/dns_records
        local result, code, err = ali_request("DeleteDomainRecord", {
            RecordId = dr.id,
        })
        if result then
            ali_log("delete dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " success", "INFO")
        else
            ali_log(
                "delete dns record " .. dr.value .. " " .. dr.rr ..
                "." .. dr.domain .. " failed: " .. code .. " " .. err,
                "ERROR")
        end
    end
end

function _M.create_dns_record(recordlist, zone_id)
    for _, dr in ipairs(recordlist) do
        -- /zones/{zone_id}/dns_records
        local result, code, err = ali_request("AddDomainRecord", dnsrecord_to_alirecord(dr))
        if result then
            ali_log("create dns record " .. dr.value .. " " .. dr.rr .. "." .. dr.domain .. " success", "INFO")
        else
            ali_log(
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
    if init_info.auth.ak_id and init_info.auth.ak_secret then
        ak_id = init_info.auth.ak_id
        ak_secret = init_info.auth.ak_secret
    else
        return nil, "invalid auth type"
    end
    log = init_info.log or require("mods.log").init()
    return _M
end

return _M
