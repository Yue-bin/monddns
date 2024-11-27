local log = {}

-- 日志相关
-- 搬了一点monlog
log.loglevels = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR",
    [4] = "FATAL",
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
    FATAL = 4
}
local loglevelmax = 4
local loglevelmin = 0
-- 默认日志级别

local LOG_LEVEL = log.loglevels.INFO
-- LOG_LEVEL = loglevels.DEBUG
function log.setlevel(level)
    LOG_LEVEL = level
end

-- 输出日志到控制台
-- outputstream默认为stderr
-- level默认为INFO
function log.log(msg, level, outputstream)
    outputstream = outputstream or io.stderr
    level = level or log.loglevels.INFO
    assert((level >= loglevelmin and level <= loglevelmax), "log level is invalid")
    if level >= LOG_LEVEL then
        -- 使用outputstream输出日志
        outputstream:write(os.date("%Y.%m.%d-%H:%M:%S"), " [", log.loglevels[level], "] ", msg, "\n")
    end
end

return log
