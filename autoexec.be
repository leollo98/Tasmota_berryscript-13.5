import math
import string
import json

var controlLock = true

var r = 255
var g = 255
var b = 255
var cold = 255
var warm = 255
var dimmer = 255
var HEUDimmer =255
var times = 0

def scale(value, fromLow, fromHigh, toLow, toHigh)
    return (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow) + toLow
end

def hora_minuto(hora,minuto)
    return hora*60+minuto
end

def hsv_to_rgb( h, s, v )
    if (h>=360)
        h=360
    end
    if (s>=255)
        s=255
    end
    if (v>=255)
        v=255
    end
    h = h / 360.0
    s = s / 255.0
    v = v / 255.0
        if (h >= 1.0)
            h = 0.0
        end
        var i = math.floor(h*6.0)
        var f = h*6.0 - i

        var w = v * (1.0 - s)
        var q = v * (1.0 - s * f)
        var t = v * (1.0 - s * (1.0 - f))

        if (i==0) 
            r = v*255
            g = t*255
            b = w*255
        end
        if (i==1)
            r = q*255 
            g = v*255 
            b = w*255
        end
        if (i==2)
            r = w*255 
            g = v*255 
            b = t*255
        end
        if (i==3)
            r = w*255 
            g = q*255 
            b = v*255
        end
        if (i==4)
            r = t*255 
            g = w*255 
            b = v*255
        end
        if (i==5)
            r = v*255 
            g = w*255 
            b = q*255
        end
end

def updateLamp(r,g,b,c,w)
    light.set({'rgb':string.format("%02x%02x%02x%02x%02x", r,g,b,c,w)})
    print("R:",r,"G:",g,"B:",b, "Cold:",c,"warm:",w )
end


def updateCT(CT)
    cold = scale(CT,153,500,255,0)
    warm = scale(CT,153,500,0,255)
end


def LightControl(val)
    if controlLock
        tasmota.set_power(0,val)
        tasmota.set_power(1,val)
    end
end


def myCT(time)
    if (time<=hora_minuto(1,30))
        updateCT(scale(time,hora_minuto(0,00),hora_minuto(1,30),326,500))
    elif (time>=hora_minuto(1,30) && time<hora_minuto(5,00))
        updateCT(500)
    elif (time>=hora_minuto(5,00) && time<=hora_minuto(6,00))
        updateCT(scale(time,hora_minuto(5,00),hora_minuto(6,00),500,326))
    else
        updateCT(326)
    end
end




def myDimmer(time)
    if (time<hora_minuto(1,00))
        dimmer = 204
    elif (time>=hora_minuto(1,00) && time<=hora_minuto(2,30))
        dimmer = scale(time,hora_minuto(1,00),hora_minuto(2,30),204,102)
    elif (time>hora_minuto(2,30) && time<hora_minuto(5,00))
        dimmer = 102
    elif (time>=hora_minuto(5,00) && time<=hora_minuto(6,00))
        dimmer = scale(time,hora_minuto(5,00),hora_minuto(6,00),102,204)
    else
        dimmer = 204
    end
end



def myHUE(time)
    if (time<hora_minuto(2,00))
        hsv_to_rgb( (scale(time,hora_minuto(0,00),hora_minuto(2,00),240,35)), 255, 255 )
    elif (time>=hora_minuto(2,00) && time<hora_minuto(9,15))
        hsv_to_rgb( 35, 255, 255 )
    else
        hsv_to_rgb( 240, 255, 255 )
    end
end

def myAlarm()
    print("alarm",times)
    if times==nil
        times=0
    end
    controlLock=false
    if (times<=20)
        HEUDimmer = scale(times,0,20,1,255)
        hsv_to_rgb( 38, 255, 255 )
        updateLamp(r*HEUDimmer/255,g*HEUDimmer/255,b*HEUDimmer/255,cold*dimmer/255,warm*dimmer/255)
        tasmota.set_power(0,true)
        tasmota.set_power(1,false)
        times = times + 1
        tasmota.set_timer(60000,myAlarm)
    elif (times<=30)
        times = times + 1
        tasmota.set_timer(60000,myAlarm)
    else
        hsv_to_rgb( 240, 255, 255 )
        tasmota.set_power(0,false)
        controlLock=true
        times=0
        HEUDimmer = 255
    end
end



def updateTime()
    var minutes = int(tasmota.strftime("%M", tasmota.rtc()['local']))+int(tasmota.strftime("%H", tasmota.rtc()['local']))*60
    print("time is ", minutes)
    if tasmota.get_power(1)
        myCT(minutes)
        myDimmer(minutes)
        myHUE(minutes)
        updateLamp(r*HEUDimmer/255,g*HEUDimmer/255,b*HEUDimmer/255,cold*dimmer/255,warm*dimmer/255)
    end
end

def timer()
    var sensors=json.load(tasmota.read_sensors())
    if sensors['ANALOG']['A2']<=2500
        LightControl(false)
    else
        LightControl(true)
    end
    tasmota.set_timer(500,timer)
end

timer()

tasmota.add_rule("Time#Initialized", def(values) updateTime() end )
tasmota.add_rule("Power1#State=1", def(values) updateTime() end )
tasmota.add_rule("Time#Minute", def(values) updateTime() end )

tasmota.add_cron("0 15 9 * * 2,4",myAlarm,"myAlarm")
