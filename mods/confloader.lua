---@diagnostic disable: need-check-nil
--[[
    此模块用于加载配置文件
]]

local _M = {}

local support_format = {
    "lua",
    "json",
}

local preset_conf_path = {
    "config.{format}",
    os.getenv("HOME") .. "/.config/{name}/config.{format}",
    "/usr/local/etc/{name}/config.{format}",
    "/etc/{name}/config.{format}",
}

local function test_file(file)
    local f = io.open(file, "r")
    if f == nil then
        return false
    end
    f:close()
    return true
end

local function get_format(conf_path)
    local format = string.match(conf_path, "%.(%a+)$")
    for _, v in ipairs(support_format) do
        if v == format then
            return format
        end
    end
    return nil
end

local function search_conf(name)
    for _, path in ipairs(preset_conf_path) do
        for _, format in ipairs(support_format) do
            local conf_path = string.gsub(path, "{name}", name)
            conf_path = string.gsub(conf_path, "{format}", format)
            if is_rel_path(conf_path) then
                conf_path = PATH .. conf_path
            end
            if test_file(conf_path) then
                return conf_path, format
            end
        end
    end
    return nil
end

function _M.load_conf(name, arg)
    local conf_path, format
    if (arg[1] == "-c" or arg[1] == "--conf") and arg[2] ~= nil then
        conf_path = arg[2]
        format = get_format(conf_path)
        if format == nil then
            print("unsupported configuration file format")
            return nil
        end
        if not test_file(conf_path) then
            print("could not open configuration file " .. conf_path)
        end
    else
        conf_path, format = search_conf(name)
        if conf_path == nil then
            print("configuration file not found")
            return nil
        end
    end
    print("using configuration file: " .. conf_path)
    if format == "json" then
        local json = require("cjson")
        local conf = io.open(conf_path, "r")
        local conf_table = json.decode(conf:read("*a"))
        conf:close()
        return conf_table
    elseif format == "lua" then
        local env = {}
        local config_chunk = loadfile(conf_path, "t", env)
        -- 兼容lua5.1和luajit
        if _VERSION == "Lua 5.1" then
            ---@diagnostic disable-next-line: deprecated, param-type-mismatch
            setfenv(config_chunk, env)
        end
        config_chunk()
        return env.config
    end
end

return _M
