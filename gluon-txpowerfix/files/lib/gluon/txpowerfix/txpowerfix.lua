#!/usr/bin/lua

site = require("gluon.site_config")
uci = require('luci.model.uci').cursor()

--- wrapper for calling systemcommands
function cmd(_command)
        local f = io.popen(_command)
        local l = f:read("*a")
        f:close()
        return l
end

--- first of all, get the right 2.4GHz wifi interface
local interface24 = false
local interface50 = false
if uci:get('wireless', 'radio0', 'hwmode') then
        hwmode = uci:get('wireless', 'radio0', 'hwmode')
        if hwmode == '11ng' or hwmode == '11g' then
                interface24 = 'radio0'
                hwmodeR1 = uci:get('wireless', 'radio1', 'hwmode')
                if hwmodeR1 == '11na' or  hwmodeR1 == '11a' then
                        interface50 = 'radio1'
                end
        elseif hwmode == '11na' or  hwmode == '11a'then
                interface50 = 'radio0'
                hwmodeR1 = uci:get('wireless', 'radio1', 'hwmode')
                if hwmodeR1 == '11ng' or  hwmodeR1 == '11g' then
                        interface24 = 'radio1'
                end
        else
                os.exit(0) -- something went wrong
        end
end

--- determine country
channel = uci:get('wireless', interface24, 'channel')
if channel == '13' then
        country = 'DE'
elseif channel == '12' then
        country = 'DE'
else
        country = 'US'
end

--- set values (1st pass)
uci:set('wireless', interface24, 'country', country)
uci:set('wireless', interface24, 'htmode', 'HT20')
uci:set('wireless', interface24, 'channel', channel) 
uci:save('wireless')
uci:commit('wireless')
t = cmd('sleep 2')
t = cmd('/sbin/wifi')
t = cmd('sleep 8')

--- get maximum available power and step
t = cmd('iwinfo ' .. interface24 .. ' txpowerlist | tail -n 2 | head -n 1 | awk \'{print $1}\'')
maximumTxPowerDb = string.gsub(t, "\n", "")
maximumTxPowerDb = tonumber(maximumTxPowerDb)

if maximumTxPowerDb < 30 then
        t = cmd('iwinfo ' .. interface24 .. ' txpowerlist | wc -l')
        maximumTxPower = string.gsub(t, "\n", "")
        maximumTxPower = tonumber(maximumTxPower)-1
else
        t = cmd('iwinfo ' .. interface24 .. ' txpowerlist | grep -n "19 dBm" | cut -f1 -d\':\'')
        maximumTxPower = string.gsub(t, "\n", "")
        maximumTxPower = tonumber(maximumTxPower)-1
end

--- set values (2nd pass)
uci:set('wireless', interface24, 'txpower', maximumTxPower)
uci:save('wireless')
uci:commit('wireless')

--- apply values
t = cmd('/sbin/wifi')
t = cmd('sleep 2')
