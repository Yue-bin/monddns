#!/usr/bin/env lua
---@diagnostic disable: different-requires

-- monddns.lua
-- A simple dynamic DNS script
local log = require("mods/log")
local dnsrecord = require("mods/dnsrecord")
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

-- 遍历配置文件中每一个配置
for _, c in ipairs(conf.confs) do
    g_log:log("Processing conf " .. c.name, "INFO")
    if c.service_provider == "cloudflare" then
        -- 初始化
        local cf = require("mods/cloudflare")
        local cf_ins = nil
        local cf_err = nil
        if c.auth.api_token then
            g_log:log("Using API Token auth for " .. c.name, "INFO")
            cf_ins, cf_err = cf.new {
                auth = {
                    api_token = c.auth.api_token
                },
                log = g_log
            }
        elseif c.auth.email and c.auth.api_key then
            g_log:log("Using Email + API Key auth for " .. c.name, "INFO")
            cf_ins, cf_err = cf.new {
                auth = {
                    email = c.auth.email,
                    api_key = c.auth.api_key
                },
                log = g_log
            }
        else
            g_log:log("Invalid auth configuration for " .. c.name, "ERROR")
            goto g_continue
        end
        if cf_ins == nil then
            g_log:log("Failed to initialize cloudflare instance for " .. c.name .. ": " .. cf_err, "ERROR")
            goto g_continue
        end

        -- 获取zone_id
        local zone_id, code, err = cf_ins.get_zone_id(c.domain)
        if zone_id == nil then
            g_log:log("Failed to get zone_id for " .. c.name .. ": " .. code .. " " .. err, "ERROR")
            goto g_continue
        end

        code = nil
        err = nil

        -- 处理配置中每一个子域名
        local new_recordlist = dnsrecord.new_recordlist()
        for _, sub in ipairs(c.subs) do
            -- 获取现有的dns记录
            local recordlist, code, err = cf_ins.get_dns_records(sub.sub_domain, zone_id)
            if recordlist == nil then
                g_log:log(
                    "Failed to get dns records for " .. c.name .. " " .. sub.sub_domain .. ": " .. code .. " " .. err,
                    "ERROR")
                goto sub_continue
            end
            g_log:log("Got dns record with lenth " .. #recordlist, "INFO")
            g_log:log("those dns records are " .. table.concat(recordlist, ", "), "INFO")

            for _, ip_setting in ipairs(sub.ip_list) do
                print(ip_setting.method, ip_setting.content)
                local ip_list = getip(ip_setting.method, ip_setting.content)
                if ip_list == nil then
                    g_log:log("Failed to get IP for " .. c.name .. " " .. sub.sub_domain, "ERROR")
                    goto getip_continue
                end
                for _, ip in ipairs(ip_list) do
                    new_recordlist = new_recordlist + dnsrecord.new_dnsrecord {
                        rr = sub.sub_domain,
                        domain = c.domain,
                        type = ip_setting.type,
                        value = ip,
                        ttl = 120
                    }
                end
                ::getip_continue::
            end
            ::sub_continue::
        end
    end
    ::g_continue::
end

-- Get Realtime IP Address

-- Get DNS Record

-- Compare IP Address with DNS Record and Update
