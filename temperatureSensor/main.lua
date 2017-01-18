MQTT_BrokerIP = "192.168.64.39"
MQTT_BrokerPort = 1883
MQTT_ClientID = "esp-001"
MQTT_Client_user = "user"
MQTT_Client_password = "password"
DS18B20_PIN = 5
TOPIC=my_MAC.."/DS18B20/"

--START
function getTemp(ds18b20)
    addrs = ds18b20.addrs()
    if (addrs ~= nil) then
        --print("Total DS18B20 sensors: "..table.getn(addrs))
        aTemp={}
        for j=1, table.getn(addrs)
        do
            tmp=ds18b20.read(addrs[j])
            aTemp[j]=tmp
            --print("Temp "..j..": "..aTemp[j].." C")
        end
        return aTemp
    end
    return {}
end

AP_SSID, AP_pass = getAPParamsFromFile()
if(AP_SSID == nil) then return end
wifi.setmode(wifi.STATION)
wifi.sta.config(AP_SSID, AP_pass);
wifi.sta.connect()
print("MAC:  "..my_MAC.."\n");
t=require('ds18b20')
t.setup(DS18B20_PIN)
aTemp=getTemp(t)
print("Total DS18B20 sensors: "..table.getn(aTemp))
for j=1, table.getn(aTemp)
do
    print("Temp "..j..": "..aTemp[j].." C")
end

local wifi_status_old = 0

tmr.alarm(0, 10*1000, 1, function()
    print("Check WiFi status: old="..wifi_status_old..", new="..wifi.sta.status())
    local aTemp=getTemp(t)
    for j=1, table.getn(aTemp)
    do
       print("Temp "..j..": "..aTemp[j].." C")
    end
    if wifi.sta.status() == 5 then -- подключение есть
        if wifi_status_old ~= 5 then -- Произошло подключение к Wifi, IP получен
            print(wifi.sta.getip())

            m = mqtt.Client(MQTT_ClientID, 120, MQTT_Client_user, MQTT_Client_password)

            -- Определяем обработчики событий от клиента MQTT
            m:on("connect", function(client) print ("connected") end)
            m:on("offline", function(client) 
                tmr.stop(1)
                print ("offline") 
            end)
            m:on("message", function(client, topic, data) 
                print(topic .. ":" ) 
                if data ~= nil then
                    print(data)
                end
            end)

            m:connect(MQTT_BrokerIP, MQTT_BrokerPort, 0, 1, function(conn) 
                print("connected")
            
                -- Подписываемся на топики если нужно
                --m:subscribe("/var/#",0, function(conn) 
                --end)
                    
                tmr.alarm(1, 30*1000, 1, function()
                    -- Делаем измерения, публикуем их на брокере
                    --local status,temp,humi,temp_decimal,humi_decimal = dht.read(DHT_PIN)
                    
                    local temp = ds18b20.read()
                    if(temp) then 
                        print("Temp: "..temp.." C")
                        m:publish(TOPIC.."TEMP", temp, 0, 0, function(conn) print("sent") end)
                    else
                    end
                end)
            end)
        else
            -- подключение есть и не разрывалось, ничего не делаем
        end
    else
        print("Reconnect "..wifi_status_old.." "..wifi.sta.status())
        tmr.stop(1)
        wifi.sta.connect()
    end

    -- Запоминаем состояние подключения к Wifi для следующего такта таймера
    wifi_status_old = wifi.sta.status()
end)


