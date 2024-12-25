--[[
    这个模块用于按照配置给出的方法获取IP地址
    暂时不对获取的IP地址进行校验

    这里的所有函数都返回
        成功：一个数组，每一个元素是一个IP地址
        失败：nil, code, err
]]
local http = require("socket.http")

-- 从url获取ip
local function from_url(url)
    local body, code, headers, status = http.request(url)
    if code == 200 then
        local ip_list = {}
        for line in string.gmatch(body, "[^\r\n]+") do
            table.insert(ip_list, line)
        end
        return ip_list
    else
        return nil, code, (body or "")
    end
end

-- 从命令获取ip
local function from_cmd(cmd)
    local f, err = io.popen(cmd)
    if f then
        local ip_list = {}
        for line in f:lines() do
            table.insert(ip_list, line)
        end
        f:close()
        return ip_list
    else
        return nil, 0, (err or "")
    end
end

-- 从固定值获取ip
local function from_value(value)
    return { value }
end

-- 选择获取ip的方法
local function selector(method, content)
    if method == "url" then
        return from_url(content)
    elseif method == "cmd" then
        return from_cmd(content)
    elseif method == "static" then
        return from_value(content)
    else
        return nil, 0, "unknown method"
    end
end

return selector
