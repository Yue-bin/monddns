#!/usr/bin/env lua
---@diagnostic disable: different-requires

-- monddns.lua
-- A simple dynamic DNS script
local log = require("mods/log")
local dnsrecord = require("mods/dnsrecord")

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
            goto continue
        end
        if cf_ins == nil then
            g_log:log("Failed to initialize cloudflare instance for " .. c.name .. ": " .. cf_err, "ERROR")
            goto continue
        end

        -- 获取zone_id
        local zone_id, code, err = cf_ins.get_zone_id(c.domain)
        if zone_id == nil then
            g_log:log("Failed to get zone_id for " .. c.name .. ": " .. code .. " " .. err, "ERROR")
            goto continue
        end

        code = nil
        err = nil
        -- 获取现有的dns记录
        local recordlist, code, err = cf_ins.get_dns_records(zone_id)

        -- 将配置文件中的记录转换为recordlist类型
    end
    ::continue::
end

-- Get Realtime IP Address

-- Get DNS Record

-- Compare IP Address with DNS Record and Update
