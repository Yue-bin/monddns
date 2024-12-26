#!/usr/bin/env lua5.4
---@diagnostic disable: different-requires

-- monddns.lua
-- A simple dynamic DNS script
local log = require("mods/log")
local dnsrecord = require("mods/dnsrecord")
local json = require("cjson")
local getip = require("mods/getip")

-- Parse Configuration
local conf = require("mods/confloader").load_conf("monddns", arg)
if conf == nil then
    print("Failed to load configuration")
    os.exit(1)
end
local log_file = io.open(conf.log.path, "a")
local g_log = log.init(log_file)
g_log:setlevel(conf.log.level or "INFO")

-- 服务商实例工厂，根据给定的provider返回对应的实例
-- 要求每个provider的实例都有get_zone_id, get_dns_records, delete_dns_record, create_dns_record方法
-- 且这些方法的参数和返回值都是一致的
local processer = {
}
-- cloudflare
function processer.cloudflare(config)
    -- 初始化
    local cf = require("mods/cloudflare")
    local cf_ins, cf_err = cf.new {
        auth = {
            api_token = config.auth.api_token,
            email = config.auth.email,
            api_key = config.auth.api_key,
        },
        log = g_log,
    }
    if cf_ins == nil then
        g_log:log("Failed to initialize cloudflare instance for " .. config.name .. ": " .. cf_err, "ERROR")
        return nil
    end
    return cf_ins
end

-- Main Loop
-- 遍历配置文件中每一个配置
g_log:log("Start processing", "INFO")
for _, config in ipairs(conf.confs) do
    g_log:log("Processing conf " .. config.name, "INFO")
    if processer[config.provider] then
        local ps_ins = processer[config.provider](config)
        if ps_ins == nil then
            g_log:log("Failed to initialize instance for " .. config.name, "ERROR")
            goto g_continue
        end

        -- 获取zone_id
        local zone_id, code, err = ps_ins.get_zone_id(config.domain)
        if zone_id == nil then
            g_log:log("Failed to get zone_id for " .. config.name .. ": " .. code .. " " .. err, "ERROR")
            return
        end

        code = nil
        err = nil

        -- 处理配置中每一个子域名
        for _, sub in ipairs(config.subs) do
            g_log:log("Processing sub domain " .. sub.sub_domain, "INFO")
            -- 获取现有的dns记录
            local recordlist, code, err = ps_ins.get_dns_records(sub.sub_domain .. "." .. config.domain, zone_id)
            if recordlist == nil then
                g_log:log(
                    "Failed to get dns records for " ..
                    config.name .. " " .. sub.sub_domain .. ": " .. code .. " " .. err,
                    "ERROR")
                goto sub_continue
            end
            code = nil
            err = nil
            g_log:log("Got dns record with lenth " .. #recordlist, "INFO")
            if #recordlist ~= 0 then
                g_log:log("those dns records are " .. json.encode(recordlist), "DEBUG")
            end

            -- 获取新的dns记录
            local new_recordlist = dnsrecord.new_recordlist()
            for _, ip_setting in ipairs(sub.ip_list) do
                local ip_list, code, err = getip(ip_setting.method, ip_setting.content)
                if ip_list == nil then
                    g_log:log(
                        "Failed to get IP for " .. config.name .. " " .. sub.sub_domain .. " with code " .. code ..
                        " error " .. err, "ERROR")
                    goto getip_continue
                end
                code = nil
                err = nil
                g_log:log("Got " .. #ip_list .. " IPs with " .. ip_setting.method .. " " .. ip_setting.content, "INFO")
                if #ip_list ~= 0 then
                    g_log:log("those IPs are " .. table.concat(ip_list, ", "), "DEBUG")
                end
                for _, ip in ipairs(ip_list) do
                    new_recordlist = new_recordlist .. dnsrecord.new_dnsrecord {
                        rr = sub.sub_domain,
                        domain = config.domain,
                        type = ip_setting.type,
                        value = ip,
                        ttl = 1
                    }
                end
                ::getip_continue::
            end

            -- 比较现有的dns记录和新的dns记录
            local to_delete = recordlist - new_recordlist
            local to_add = new_recordlist - recordlist
            g_log:log(#to_delete .. " records to delete", "INFO")
            g_log:log("To delete: " .. json.encode(to_delete), "DEBUG")
            g_log:log(#to_add .. " records to add", "INFO")
            g_log:log("To add: " .. json.encode(to_add), "DEBUG")

            -- 删除多余的dns记录
            ps_ins.delete_dns_record(to_delete, zone_id)

            -- 添加新的dns记录
            ps_ins.create_dns_record(to_add, zone_id)
            ::sub_continue::
        end
    else
        g_log:log("Unknown provider " .. config.provider, "ERROR")
    end
    ::g_continue::
end
g_log:log("End processing", "INFO")
