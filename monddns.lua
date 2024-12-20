#!/usr/bin/env lua

-- monddns.lua
-- A simple dynamic DNS script
---@diagnostic disable-next-line: different-requires
local log = require("mods/log")
local dnsrecord = require("mods/dnsrecord")


-- Parse Configuration
local conf = require("mods/confloader").load_conf("monddns", arg)
print(conf.name)

-- Get Realtime IP Address
local rl_local = dnsrecord.new_recordlist()

-- Get DNS Record

-- Compare IP Address with DNS Record and Update
