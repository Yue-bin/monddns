--[[
    此处定义dnsrecord类型和recordlist类型
--]]

local base = _G

-- dnsrecord类型
-- 示例:web.example.com
local dnsrecord = {
    rr = "",    -- web
    domin = "", -- example.com
    type = "",  -- A
    value = "", -- 1.2.3.4
    ttl = 1,    -- 1
}

-- dnsrecord判断相等,使用==
local function dnsrecord_equal(dr1, dr2)
    return dr1.rr == dr2.rr and dr1.domin == dr2.domin and dr1.type == dr2.type and dr1.value == dr2.value
end

local dnsrecord_mt = {
    __index = dnsrecord,
    __newindex = function(table, key, value)
        if rawget(dnsrecord, key) == nil then
            error("Attempt to add new field '" .. key .. "' to dnsrecord")
        else
            rawset(table, key, value)
        end
    end,
    __eq = dnsrecord_equal,
}

local function new_dr(rr, domin, type, value, ttl)
    local new_dr_obj = {
        rr = rr or "",
        domin = domin or "",
        type = type or "",
        value = value or "",
        ttl = ttl or 1
    }
    base.setmetatable(new_dr_obj, dnsrecord_mt)
    return new_dr_obj
end


-- recordlist类型
local recordlist = {}

-- recordlist判断相等,使用==
local function recordlist_equal(rl1, rl2)
    if #rl1 ~= #rl2 then
        return false
    end
    for i = 1, #rl1 do
        if not rl1[i] == rl2[i] then
            return false
        end
    end
    return true
end

-- recordlist判断是否包含某个dnsrecord,使用<
local function recordlist_contains(rl, dr)
    for i = 1, #rl do
        if rl[i] == dr then
            return true
        end
    end
    return false
end

-- recordlist添加一个dnsrecord,使用..
local function recordlist_add(rl, dr)
    if not rl < dr then
        rl[#rl + 1] = dr
    end
end

-- recordlist合并,重复项仅保留一个,使用+
local function recordlist_merge(rl1, rl2)
    local result = {}
    for i = 1, #rl1 do
        result[#result + 1] = rl1[i]
    end
    for i = 1, #rl2 do
        if not result < rl2[i] then
            result[#result + 1] = rl2[i]
        end
    end
    return result
end

-- recordlist减去另一个recordlist,使用-
local function recordlist_sub(rl1, rl2)
    local result = {}
    for i = 1, #rl1 do
        if not rl2 < rl1[i] then
            result[#result + 1] = rl1[i]
        end
    end
    return result
end

-- 限定recordlist为dnsrecord类型的列表
local recordlist_mt = {
    __index = recordlist,
    __newindex = function(table, key, value)
        if type(value) ~= "table" or getmetatable(value) ~= dnsrecord_mt then
            error("Attempt to add non-dnsrecord type to recordlist")
        else
            rawset(table, key, value)
        end
    end,
    __eq = recordlist_equal,
    __lt = recordlist_contains,
    __concat = recordlist_add,
    __add = recordlist_merge,
    __sub = recordlist_sub,
}

local function new_rl()
    local new_rl_obj = {}
    base.setmetatable(new_rl_obj, recordlist_mt)
    return new_rl_obj
end



-- 暴露dnsrecord和recordlist
return {
    new_dnsrecord = new_dr,
    new_recordlist = new_rl,
}
