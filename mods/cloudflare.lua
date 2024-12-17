local url = require("socket.url")
local http = require("socket.http")
local json = require("cjson")

--[=[
curl --request GET \
                    --url 'https://api.cloudflare.com/client/v4/zones/]] ..
        CFZoneID .. [[/dns_records?comment=]] .. require("luacurl").escape(CfComment) .. [[' \
                    --header 'Content-Type: application/json' \
                    --header 'Authorization: Bearer ]] .. CFAPIKey
--]=]

local function new_instance(api_key)
    local self = {}
    self.api_key = api_key
    self.base_url = "https://api.cloudflare.com/client/v4"
    self.headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. api_key
    }
    return self
end


return {
    new = new_instance
}
