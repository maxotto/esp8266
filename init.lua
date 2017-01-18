APREQ = "ap_request.lua"   -- File that is executed after connection

function split(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
      table.insert(result, each)
   end
   return result
end

function getAPParamsFromFile()
    if (file.open("AP_config","r"))then
        local lines = split(file:read(), "\n");       
        if lines == nil then dofile(APREQ) 
        else
            local AP_SSID = lines[1];
            local AP_pass = lines[2];
            file.close();
            return AP_SSID, AP_pass
        end
    else
        dofile(APREQ)
        return 
    end -- if file open
end


AP_SSID, AP_pass = getAPParamsFromFile()
if(AP_SSID == nil)  then return end
wifi.setmode(wifi.STATION)
wifi.sta.config(AP_SSID, AP_pass);

-- trying to conect to AP
print("Connecting to AP...");

cnt=0;
tmr.alarm(0, 1000, 1, function() 
    print("..");
    if wifi.sta.status() ~= 5 then
        cnt = cnt + 1;
        if cnt > 9 then
            print("Failed to connect AP, starting own AP and server...") 
            tmr.stop(0)
            dofile(APREQ)
     -- start TCP server для настройки AP_config
     -- tmr.alarm(0, 60000, 1, function() dofile(APREQ) end )
        end
    else
        tmr.stop(0)
        my_MAC=wifi.sta.getmac();
        print("MAC:  "..my_MAC.."\n");
        my_MAC=my_MAC:gsub(":", "-");
        print("MAC:  "..my_MAC.."\n");
        --ipd = split(wifi.sta.getip(), "\s+");
        print('IP info: '..wifi.sta.getip())
        --print(ipd);
        proceed(my_MAC);
    end
end)


function proceed(my_MAC)
-- взять с сервера модуль для данного мака и запустить его
    recieved = false;
    filename = "main.lua";
    local ip='192.168.64.39';
    local port='80';
    local path = '/esp8266/' .. my_MAC..'/'..filename;
    local dataRecieved=''
    conn = net.createConnection(net.TCP, false)
    if (conn==nil)    then 
        print("conn is nil.") 
    end

    conn:on('receive', function(sck, response)
        dataRecieved=dataRecieved..response
        recieved = true
        --print ("response start:--- \n")
        --print (response )
        --print ("response finish:_______\n")
    end)
    conn:on('disconnection', function(sck, response)
        local function reset()
            print('Reset...')
            if(recieved) then
                file.open(filename, 'w+')
                --print(dataRecieved)
                start, finish=string.find(dataRecieved,"\r\n\r\n")
                --print(start.."->"..finish)
                filedata=string.sub(dataRecieved,finish+1)
                --print(filedata)
                file.write(filedata)
                file.close()
                print(filename..' saved')
            end
            tmr.stop(0)
            dofile(filename);    
       end

       tmr.alarm(0, 2000, 1, reset)
    end)
    conn:connect(port, ip)
    conn:on("connection", function(sck, c)
        -- Wait for connection before sending.
        get="GET "..path.." HTTP/1.1\r\nHost: "..ip.."\r\nConnection: close\r\nAccept: */*\r\n\r\n"
        --print(get)
        conn:send(get);
    end)
    -- conn:send('GET /index.html HTTP/1.1 Host: 192.168.64.36 User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:48.0) Gecko/20100101 Firefox/48.0')
end
