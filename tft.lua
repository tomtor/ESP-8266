--
-- LUA driver for ESP8266 and an ILI9225 176x220 LCD display
--
-- inspired by https://github.com/jorgegarciadev/TFT_22_ILI9225
--
-- It accepts a TCP stream with n initial \n terminated command line:
--
-- raw <size of image in bytes> <width> <x> <y>
--
-- An example sh driver script which plots weather data
-- by composing an image with ImageMagick:
--
--[[
#!/bin/sh

OUT=/tmp/canvas$$.rgb

export LC_TIME=nl_NL.UTF-8

DATE1=$(date -j +"%a %e %b")
DATE2=$(date -j +"%H:%M")

convert -depth 8 -size 220x176 -pointsize 30 xc:black \
 -font ComicSans \
 -gravity northwest -fill 'rgb(0,255,0)' -draw "text 0,-6 '$1 °C'" \
 -gravity northeast -fill 'rgb(255,180,0)' -draw "text 0,-6 '$2 °C'" \
 -gravity center -fill 'rgb(99,184,255)' -draw "text 0,-38 '$3 %Rel'" \
 -gravity center -fill 'rgb(255,0,255)' -draw "text 0,38 '$4 hPa'" \
 -gravity south -fill 'rgb(255,0,0)' -draw "text 0,-6 '$5 kW'" \
 -gravity west -pointsize 26 -fill white -draw "text 0,0 '$DATE1'" \
 -gravity east -pointsize 38 -fill white -draw "text 0,0 '$DATE2'" \
 $OUT

(echo raw $(stat -f %z $OUT) 220 0 0 | cat - $OUT | nc 192.168.0.206 12345; rm $OUT) &

--]]


print("Start TFT")

node.setcpufreq(node.CPU160MHZ)

spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, spi.DATABITS_8, 2)

TFT_RS= 2
TFT_RST= 4
TFT_CS= 8
TFT_LED= 1

-- /* ILI9225 screen size */
ILI9225_LCD_WIDTH=  176
ILI9225_LCD_HEIGHT= 220

-- /* ILI9225 LCD Registers */
ILI9225_DRIVER_OUTPUT_CTRL      = 0x01 -- Driver Output Control
ILI9225_LCD_AC_DRIVING_CTRL     = 0x02 -- LCD AC Driving Control
ILI9225_ENTRY_MODE            	= 0x03 -- Entry Mode
ILI9225_DISP_CTRL1          	= 0x07 -- Display Control 1
ILI9225_BLANK_PERIOD_CTRL1      = 0x08 -- Blank Period Control
ILI9225_FRAME_CYCLE_CTRL        = 0x0B -- Frame Cycle Control
ILI9225_INTERFACE_CTRL          = 0x0C -- Interface Control
ILI9225_OSC_CTRL             	= 0x0F -- Osc Control
ILI9225_POWER_CTRL1            	= 0x10 -- Power Control 1
ILI9225_POWER_CTRL2           	= 0x11 -- Power Control 2
ILI9225_POWER_CTRL3            	= 0x12 -- Power Control 3
ILI9225_POWER_CTRL4            	= 0x13 -- Power Control 4
ILI9225_POWER_CTRL5            	= 0x14 -- Power Control 5
ILI9225_VCI_RECYCLING          	= 0x15 -- VCI Recycling
ILI9225_RAM_ADDR_SET1           = 0x20 -- Horizontal GRAM Address Set
ILI9225_RAM_ADDR_SET2           = 0x21 -- Vertical GRAM Address Set
ILI9225_GRAM_DATA_REG           = 0x22 -- GRAM Data Register
ILI9225_GATE_SCAN_CTRL          = 0x30 -- Gate Scan Control Register
ILI9225_VERTICAL_SCROLL_CTRL1   = 0x31 -- Vertical Scroll Control 1 Register
ILI9225_VERTICAL_SCROLL_CTRL2   = 0x32 -- Vertical Scroll Control 2 Register
ILI9225_VERTICAL_SCROLL_CTRL3   = 0x33 -- Vertical Scroll Control 3 Register
ILI9225_PARTIAL_DRIVING_POS1    = 0x34 -- Partial Driving Position 1 Register
ILI9225_PARTIAL_DRIVING_POS2    = 0x35 -- Partial Driving Position 2 Register
ILI9225_HORIZONTAL_WINDOW_ADDR1 = 0x36 -- Horizontal Address Start Position
ILI9225_HORIZONTAL_WINDOW_ADDR2	= 0x37 -- Horizontal Address End Position
ILI9225_VERTICAL_WINDOW_ADDR1   = 0x38 -- Vertical Address Start Position
ILI9225_VERTICAL_WINDOW_ADDR2   = 0x39 -- Vertical Address End Position
ILI9225_GAMMA_CTRL1            	= 0x50 -- Gamma Control 1
ILI9225_GAMMA_CTRL2             = 0x51 -- Gamma Control 2
ILI9225_GAMMA_CTRL3            	= 0x52 -- Gamma Control 3
ILI9225_GAMMA_CTRL4            	= 0x53 -- Gamma Control 4
ILI9225_GAMMA_CTRL5            	= 0x54 -- Gamma Control 5
ILI9225_GAMMA_CTRL6            	= 0x55 -- Gamma Control 6
ILI9225_GAMMA_CTRL7            	= 0x56 -- Gamma Control 7
ILI9225_GAMMA_CTRL8            	= 0x57 -- Gamma Control 8
ILI9225_GAMMA_CTRL9             = 0x58 -- Gamma Control 9
ILI9225_GAMMA_CTRL10            = 0x59 -- Gamma Control 10

ILI9225C_INVOFF=  0x20
ILI9225C_INVON=   0x21
 

gpio.mode(TFT_RS, gpio.OUTPUT)
gpio.mode(TFT_RST, gpio.OUTPUT)
gpio.mode(TFT_CS, gpio.OUTPUT)
gpio.mode(TFT_LED, gpio.OUTPUT)

gpio.write(TFT_LED, gpio.HIGH)

-- Initialization Code
gpio.write(TFT_RST, gpio.HIGH)
tmr.delay(1)
gpio.write(TFT_RST, gpio.LOW)
tmr.delay(10)
gpio.write(TFT_RST, gpio.HIGH)
tmr.delay(50)

-- Utilities
--
function _writeCommand(HI, LO)
  gpio.write(TFT_RS, gpio.LOW)
  gpio.write(TFT_CS, gpio.LOW)
  spi.send(1, HI, LO)
  gpio.write(TFT_CS, gpio.HIGH)
end

function _writeData(HI, LO)
  gpio.write(TFT_RS, gpio.HIGH)
  gpio.write(TFT_CS, gpio.LOW)
  spi.send(1, HI, LO)
  gpio.write(TFT_CS, gpio.HIGH)
end

function _writeRegister(reg, data)
  _writeCommand(reg / 256 , reg % 256);
  _writeData(data / 256, data % 256);
end


-- /* Start Initial Sequence */
-- /* Set SS bit and direction output from S528 to S1 */
_writeRegister(ILI9225_POWER_CTRL1, 0x0000) -- Set SAP,DSTB,STB
_writeRegister(ILI9225_POWER_CTRL2, 0x0000) -- Set APON,PON,AON,VCI1EN,VC
_writeRegister(ILI9225_POWER_CTRL3, 0x0000) -- Set BT,DC1,DC2,DC3
_writeRegister(ILI9225_POWER_CTRL4, 0x0000) -- Set GVDD
_writeRegister(ILI9225_POWER_CTRL5, 0x0000) -- Set VCOMH/VCOML voltage
tmr.delay(40) 

-- Power-on sequence
_writeRegister(ILI9225_POWER_CTRL2, 0x0018) -- Set APON,PON,AON,VCI1EN,VC
_writeRegister(ILI9225_POWER_CTRL3, 0x6121) -- Set BT,DC1,DC2,DC3
_writeRegister(ILI9225_POWER_CTRL4, 0x006F) -- Set GVDD   /*007F 0088 */
_writeRegister(ILI9225_POWER_CTRL5, 0x495F) -- Set VCOMH/VCOML voltage
_writeRegister(ILI9225_POWER_CTRL1, 0x0800) -- Set SAP,DSTB,STB
tmr.delay(10)
_writeRegister(ILI9225_POWER_CTRL2, 0x103B) -- Set APON,PON,AON,VCI1EN,VC
tmr.delay(50)

_writeRegister(ILI9225_DRIVER_OUTPUT_CTRL, 0x011C) -- set the display line number and display direction
_writeRegister(ILI9225_LCD_AC_DRIVING_CTRL, 0x0100) -- set 1 line inversion
_writeRegister(ILI9225_ENTRY_MODE, 0x1030) -- set GRAM write direction and BGR=1.
_writeRegister(ILI9225_DISP_CTRL1, 0x0000) -- Display off
_writeRegister(ILI9225_BLANK_PERIOD_CTRL1, 0x0808) -- set the back porch and front porch
_writeRegister(ILI9225_FRAME_CYCLE_CTRL, 0x1100) -- set the clocks number per line
_writeRegister(ILI9225_INTERFACE_CTRL, 0x0000) -- CPU interface
_writeRegister(ILI9225_OSC_CTRL, 0x0D01) -- Set Osc  /*0e01*/
_writeRegister(ILI9225_VCI_RECYCLING, 0x0020) -- Set VCI recycling
_writeRegister(ILI9225_RAM_ADDR_SET1, 0x0000) -- RAM Address
_writeRegister(ILI9225_RAM_ADDR_SET2, 0x0000) -- RAM Address

-- /* Set GRAM area */
_writeRegister(ILI9225_GATE_SCAN_CTRL, 0x0000) 
_writeRegister(ILI9225_VERTICAL_SCROLL_CTRL1, 0x00DB) 
_writeRegister(ILI9225_VERTICAL_SCROLL_CTRL2, 0x0000) 
_writeRegister(ILI9225_VERTICAL_SCROLL_CTRL3, 0x0000) 
_writeRegister(ILI9225_PARTIAL_DRIVING_POS1, 0x00DB) 
_writeRegister(ILI9225_PARTIAL_DRIVING_POS2, 0x0000) 
_writeRegister(ILI9225_HORIZONTAL_WINDOW_ADDR1, 0x00AF) 
_writeRegister(ILI9225_HORIZONTAL_WINDOW_ADDR2, 0x0000) 
_writeRegister(ILI9225_VERTICAL_WINDOW_ADDR1, 0x00DB) 
_writeRegister(ILI9225_VERTICAL_WINDOW_ADDR2, 0x0000) 

-- /* Set GAMMA curve */
_writeRegister(ILI9225_GAMMA_CTRL1, 0x0000) 
_writeRegister(ILI9225_GAMMA_CTRL2, 0x0808) 
_writeRegister(ILI9225_GAMMA_CTRL3, 0x080A) 
_writeRegister(ILI9225_GAMMA_CTRL4, 0x000A) 
_writeRegister(ILI9225_GAMMA_CTRL5, 0x0A08) 
_writeRegister(ILI9225_GAMMA_CTRL6, 0x0808) 
_writeRegister(ILI9225_GAMMA_CTRL7, 0x0000) 
_writeRegister(ILI9225_GAMMA_CTRL8, 0x0A00) 
_writeRegister(ILI9225_GAMMA_CTRL9, 0x0710) 
_writeRegister(ILI9225_GAMMA_CTRL10, 0x0710) 

_writeRegister(ILI9225_DISP_CTRL1, 0x0012) 
tmr.delay(50) 
_writeRegister(ILI9225_DISP_CTRL1, 0x1017)

_bgColor = 0
_orientation= 0

_maxX = ILI9225_LCD_WIDTH
_maxY = ILI9225_LCD_HEIGHT

function _orientCoordinates(x1, y1)
    if _orientation == 0 then return x1, y1
    elseif _orientation == 1 then return _maxY - y1 - 1, x1
    elseif _orientation == 2 then return _maxX - x1 - 1, _maxY - y1 - 1
    else return y1, _maxX - x1 - 1 end
end

function setOrientation(orientation)
    _orientation = orientation % 4
    if _orientation == 0 then
        _maxX = ILI9225_LCD_WIDTH
        _maxY = ILI9225_LCD_HEIGHT
    elseif _orientation == 1 then
        _maxX = ILI9225_LCD_HEIGHT
        _maxY = ILI9225_LCD_WIDTH
    elseif orientation == 2 then
        _maxX = ILI9225_LCD_WIDTH
        _maxY = ILI9225_LCD_HEIGHT
    else
        _maxX = ILI9225_LCD_HEIGHT
        _maxY = ILI9225_LCD_WIDTH
    end
end

function _setWindow(x0, y0, x1, y1)
    x0, y0 = _orientCoordinates(x0, y0)
    x1, y1= _orientCoordinates(x1, y1)

    if x1<x0 then x0, x1= x1, x0 end
    if y1<y0 then y0, y1= y1, y0 end

    _writeRegister(ILI9225_HORIZONTAL_WINDOW_ADDR1,x1)
    _writeRegister(ILI9225_HORIZONTAL_WINDOW_ADDR2,x0)

    _writeRegister(ILI9225_VERTICAL_WINDOW_ADDR1,y1)
    _writeRegister(ILI9225_VERTICAL_WINDOW_ADDR2,y0)

    _writeRegister(ILI9225_RAM_ADDR_SET1,x0)
    _writeRegister(ILI9225_RAM_ADDR_SET2,y0)

    _writeCommand(0x00, 0x22)
end

function RGB888_RGB565(color)
    return bit.bor(
        bit.lshift(bit.band(bit.rshift(color,19), 0x1f), 11),
        bit.lshift(bit.band(bit.rshift(color,10), 0x3f), 5),
        bit.band(bit.rshift(color,3), 0x1f)
    )
end

function writen()
    l= _n
    if l > 64 then
      l= 64
    end
    gpio.write(TFT_RS, gpio.HIGH)
    gpio.write(TFT_CS, gpio.LOW)
    for i= 1, l do 
      spi.send(1, _HI, _LO)
    end
    gpio.write(TFT_CS, gpio.HIGH)
    if _n > 64
    then
      _n= _n - 64
      tmr.alarm(0, 2, 0, writen)
    end
end
  
function twrite(n, HI, LO)
    _n= n
    _HI= HI
    _LO= LO
    writen()
end

function fillRectangle(x1, y1, x2, y2, color)
    _setWindow(x1, y1, x2, y2)
    twrite((y2 - y1 + 1) * (x2 - x1 + 1), color / 256, color)
end

function clear()
    local old = _orientation
    setOrientation(0)
    fillRectangle(0, 0, _maxX - 1, _maxY - 1, _bgColor)
    setOrientation(old)
    tmr.delay(10)
end

-- tmr.alarm(1,10,0,clear)

---------------------------------------------------

setOrientation(1) -- use 0 for portrait

_cnt= 0
_sck= 0

_size= 0
_width= 0
_x= 0
_y= 0

function receiver(sck, data)

  if _cnt == 0 then
    _sck= sck
    local ind= data:find("\n")
    if ind == nil then
      sck:close()
      print("no cmd")
      return
    end
    local cmd= data:sub(1,ind)
    local words = {}
    for word in cmd:gmatch("%w+") do table.insert(words, word) end
    print(words[1])
    data= data:sub(ind+1)
    _size= tonumber(words[2])
    _width= tonumber(words[3])
    _x= tonumber(words[4])
    _y= tonumber(words[5])
  elseif sck ~= _sck then
    sck:close()
    print("dup")
    return
  end

  for i= 1, data:len() do
    if _cnt % (3 * _width) == 0 then
      _setWindow(_x, _y + _cnt / (3*_width), _x + _width - 1, _y + _cnt / (3*_width))
      gpio.write(TFT_RS, gpio.HIGH)
      gpio.write(TFT_CS, gpio.LOW)
    end
    mod= _cnt % 3
    local b= string.byte(data, i)
    if mod == 0 then
      red= b
    elseif mod == 1 then
      green= b
    else
      spi.send(1,
          red / 8 * 8 + green / 32,        
          green / 4 * 32 + b / 8)
    end
    _cnt= _cnt + 1
  end
  
  if _cnt == _size then
    sck:close()
  end
end

function disconnect(sck)
    if sck == _sck then
        gpio.write(TFT_CS, gpio.HIGH)
        print("discon")
        sck:close()
        _cnt= 0
    else
        print("drop")
    end
end

telnet_srv = net.createServer(net.TCP, 10)
telnet_srv:listen(12345, function(conn)
    conn:on("receive", receiver)
    conn:on("disconnection", disconnect)
end)
