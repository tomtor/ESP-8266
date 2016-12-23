--
-- Drive a 5x8 40 RGB LED WS2812 matrix board like:
--
-- https://www.sparkfun.com/products/retired/12663
--
-- with a horizontal scrolling (text) display.
--
--
-- It uses the standard telnet server, so you can update scripts and access the device.
--
-- A line starting with
--
-- !matrix
--
-- will be folowed with a space (0x20 byte) and the next bytes are:
--
-- speed: 1 byte with the scroll delay in units of 0.01 second.
--
-- background color: 3 bytes (Green, Red, Blue)
--
-- the horizontal lines data:
--
-- 5 sets of data for each horizontal line, 3 bytes (Red/Green/Blue) for each pixel.
--
-- The display will start with just the background color.
-- The image will scroll in from the right side and exit on the left side,
-- and than it will be shown again and again until a new !matrix command is received.
--
-- You can use the matrix.py script to send texts.
--


print("Start Matrix")

ws2812.init()

local i, b = 0, ws2812.newBuffer(40, 3); b:fill(0, 0, 0); tmr.alarm(0, 50, 1, function()
        i=i+1
        b:fade(2)
        b:set(i%b:size()+1, math.random(40), math.random(40), math.random(40))
        ws2812.write(b)
end)
 
telnet_srv = net.createServer(net.TCP, 180)
telnet_srv:listen(23, function(socket)
    local fifo = {}
    local fifo_drained = true

    local function sender(c)
        if #fifo > 0 then
            c:send(table.remove(fifo, 1))
        else
            fifo_drained = true
        end
    end

    local function s_output(str)
        table.insert(fifo, str)
        if socket ~= nil and fifo_drained then
            fifo_drained = false
            sender(socket)
        end
    end

    node.output(s_output, 0)   -- re-direct output to function s_ouput.

    socket:on("receive", function(c, l)
        if string.find(l,"!matrix") == 1
        then
            --print("matrix:")
            tmr.unregister(0)
            local s = string.sub(l,13)
            local speed= l:byte(9)
            local bg1= l:byte(10)
            local bg2= l:byte(11)
            local bg3= l:byte(12)
            local l = string.len(s)/3
            local b = ws2812.newBuffer(40, 3)
            local d = ws2812.newBuffer(l, 3)
            l= l/5
            local count = l
            local shown = 0
            d:replace(s)
            b:fill(bg1, bg2, bg3)
            ws2812.write(b)
            tmr.alarm(0, speed * 10, 1, function()
                local r,i
                b:shift(-1)
                for r= 1,5 do
                    i= r*8
                    if count > 0
                    then
                        b:set(i,d:get(1+r*l-count))
                    else
                        b:set(i, {bg1,bg2,bg3})
                    end                  
                end
                ws2812.write(b)
                count= count-1
                if count == -7 then
                    shown = shown + 1
                    print(shown)
                end
                if count == -8 then
                    count = l
                end
            end)
        else
            node.input(l)           -- works like pcall(loadstring(l)) but support multiple separate line
        end
    end)
    socket:on("disconnection", function(c)
        node.output(nil)        -- un-regist the redirect output function, output goes to serial
    end)
    socket:on("sent", sender)

    print("Welcome to NodeMCU Matrix world.")
end)
