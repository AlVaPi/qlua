-- nick-h@yandex.ru
-- Glukk Inc �

local w32 = require("w32")

--CLASS_CODE        = '' --����� � ����� ��������
CLASS_CODE        = "TQBR"              -- ��� ������
--CLASS_CODE        = 'SPBFUT'             -- ��� ������
--CLASS_CODE        = 'QJSIM'
SEC_CODE = '' -- ������ � ����� ��������
SEC_CODES = {}

INTERVAL = 15 -- --������� ��������

START_TIME                    = '10:00:00'               -- ������ ��������
STOP_TIME                     = '18:50:00'               -- ��������� ��������

PocketPopAll = false -- ��������� ��� ���������� �� ������� ����������
PocketPopAll_time = '10:00:05' -- ����� ����� ���� ��������� ��� ���������� �� ������� ����������
isPocketPopAll_done = false
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

--/*������� ���������� ������ (������ �� �����)*/
isRun = true -- ���� ����������� ������ �������
is_Connected = 0
PrevDayNumber                 = 0

trans_id          = os.time()            -- ������ ��������� ����� ID ����������
trans_Status      = nil                  -- ������ ������� ���������� �� ������� OnTransPeply
trans_result_msg  = ''                   -- ��������� �� ������� ���������� �� ������� OnTransPeply
numberOfFixedColumns = 0                 -- ����� ������������� ������� �� ��������
numberOfVisibleColumns = 0               -- ����� ������� ������� ��������
tableIndex = {}                          -- ������� ������� ��������� �������
openedDS = {}

t_id = nil
tv_id = nil
thist_id = nil

SeaGreen=12713921		--	RGB(193, 255, 193) �����-�������
RosyBrown=12698111	--	RGB(255, 193, 193) �����-�������


SEC_PRICE_STEP    = 0                    -- ��� ���� �����������
DS                = nil                  -- �������� ������ ������� (DataSource)
g_previous_time   = os.time() -- ��������� � ���������� ������� ������� � ������� HHMMSS

SEC_CODE_INDEX = {} -- last interval index

isDayInterval = false -- ���� ������� ��������
dayIntervalIndex = nil
UpdateDataSecQty = 10   -- ���������� ������ �������� ��������� ������ � ������� ����� ������������� �����������


 -----------------------------
 -- �������� ������� --
 -----------------------------
function DataSource(i,cell)
    local seccode = SEC_CODES['sec_codes'][i]
    local classcode = SEC_CODES['class_codes'][i]
    local interval = INTERVALS['values'][cell]

    if openedDS[i][interval] ~= nil then
        return openedDS[i][interval]
    end
    local ds = CreateDataSource(classcode,seccode,interval)
    if ds == nil then
        message('NRTR monitor: ������ ��������� ������� � ������! '..Error)
        myLog('NRTR monitor: ������ ��������� ������� � ������! '..Error)
        -- ��������� ���������� �������
        isRun = false
        return
    end
    if ds:Size() == 0 then
        ds:SetEmptyCallback()
        SEC_CODES['isEmpty'][i] = true
    end
    openedDS[i][interval] = ds
    return ds
end

do---- ����/�����

    -- ���� ����������� � �������, ����� ���� ���� ��� UpdateDataSecQty ������ ��������� ����������� ������ � �������
    function WaitUpdateDataAfterReconnect()
       while isRun and isConnected() == 0 do sleep(100) end
       if isRun then sleep(UpdateDataSecQty * 1000) end
       -- ��������� �������� ���� ���������� ����� ��������� ���������
       if isRun and isConnected() == 0 then WaitUpdateDataAfterReconnect() end
    end

    -- ���������� ������� ����/����� ������� � ���� ������� datetime
    function GetServerDateTime()

        local dt = {}

       -- �������� �������� ����/����� �������
       while isRun and dt.day == nil do
          dt.day,dt.month,dt.year,dt.hour,dt.min,dt.sec = string.match(getInfoParam('TRADEDATE')..' '..getInfoParam('SERVERTIME'),"(%d*).(%d*).(%d*) (%d*):(%d*):(%d*)")
          -- ���� �� ������� ��������, ��� ������ �����, ���� ����������� � ��������� � ������� ���������� ������
          --if dt.day == nil or isConnected() == 0 then WaitUpdateDataAfterReconnect() end
          if dt.day == nil or isConnected() == 0 then
                return os.date('*t', os.time())
                --WaitUpdateDataAfterReconnect()
           end
       end

       -- ���� �� ����� �������� ������ ��� ���������� �������������, ���������� ������� datetime ����/������� ����������, ����� �� ������� ������ ������� � �� ������� ������ � ���������
       if not isRun then return os.date('*t', os.time()) end

       -- �������� ���������� �������� � ���� number
       for key,value in pairs(dt) do dt[key] = tonumber(value) end

       -- ���������� �������� �������
       return dt
    end

    -- �������� ����� �� ���������� ������� ��:��:CC � ������� datetime
    function StrToTime(str_time)
        if type(str_time) ~= 'string' then return os.date('*t') end
        local sdt = GetServerDateTime()
        while isRun and sdt.day == nil do sleep(100) sdt = GetServerDateTime() end
        if not isRun then return os.date('*t') end
        local dt = sdt
        local h,m,s = string.match( str_time, "(%d%d):(%d%d):(%d%d)")
        dt.hour = tonumber(h)
        dt.min = tonumber(m)
        dt.sec = s==nil and 0 or tonumber(s)
        return dt
    end

end--- ����/�����

 -- ������� ��������� ������������� ������� (���������� ���������� QUIK � ����� ������)
function OnInit()

    dofile (getScriptPath().."\\monitorStepNRTR.lua") --stepNRTR ��������. ������������� - initstepNRTR, ������ - stepNRTR
    dofile (getScriptPath().."\\monitorEMA.lua") --EMA ��������. ������������� - initEMA, ������ - EMA, allEMA
    dofile (getScriptPath().."\\monitorRSI.lua") --EMA ��������. ������������� - initRSI, ������ - RSI
    dofile (getScriptPath().."\\monitorReg.lua") --��������� ��������. ������������� - initReg, ������ - Reg
    dofile (getScriptPath().."\\monitorVolume.lua") --RT �������� �������� ����������� ������. ������������� - initVolume, ������ - Volume
    dofile (getScriptPath().."\\monitorVSA.lua") --VSA ��������. ������������� - initVSA, ������ - VSA
    dofile (getScriptPath().."\\monitorRange.lua") --range

    --������ ���� ���� ������� �������
    dofile (getScriptPath().."\\scriptMonitorPar.lua") --stepNRTR ��������. ������������� - initstepNRTR, ������ - stepNRTR

    logFile = io.open(FILE_LOG_NAME, "a+") -- ��������� ����

    local ParamsFile = io.open(PARAMS_FILE_NAME,"r")
    if ParamsFile == nil then
        isRun = false
        message("�� �������� ��������� ���� ��������!!!")
        return false
    end

    --is_Connected = isConnected()
    --
    --if is_Connected ~= 1 then
    --    isRun = false
    --    message("��� ����������� � �������!!!")
    --    return false
    --end

    SEC_CODES['class_codes'] =              {} -- CLASS_CODE
    SEC_CODES['names'] =                    {} -- ����� �����
    SEC_CODES['sec_codes'] =                {} -- ���� �����
    SEC_CODES['isMessage'] =                {} -- �������� ���������
    SEC_CODES['isPlaySound'] =              {} -- ����������� ����
    SEC_CODES['volume'] =                   {} -- ������� �����
    SEC_CODES['isEmpty'] =                  {} -- ������� ������ ������
    SEC_CODES['DS'] =                       {} -- ������ �� �����������
    SEC_CODES['calcAlgoValues'] =           {} -- ������������ ������
    SEC_CODES['dayATR'] =                   {} -- ������������ ������ ATR
    SEC_CODES['dayDS'] =                    {} -- ������ ��� ATR
    SEC_CODES['dayATR_Period'] =            {} -- ������ ������ ATR
    SEC_CODES['D_minus5'] =                 {} -- ���� 5 ���� �����
    SEC_CODES['lastTimeCalculated'] =       {} -- ����� ���������� ��������
    SEC_CODES['lastrealTimeCalculated'] =   {} -- ����� ���������� �������� realtime ���������

    myLog("______________________________________________________")
    myLog("������ ���� ����������")
	
	local sec_list = getClassSecurities(CLASS_CODE)
	local lineCount = 1
	for sec in string.gmatch(sec_list, "[^,]+") do
		SEC_CODES['class_codes'][lineCount] = CLASS_CODE
		SEC_CODES['names'][lineCount] = getSecurityInfo(CLASS_CODE, sec).short_name
		SEC_CODES['sec_codes'][lineCount] = sec
		SEC_CODES['isMessage'][lineCount] = 1
		SEC_CODES['isPlaySound'][lineCount] = 0
		SEC_CODES['volume'][lineCount] = 1
		SEC_CODES['isEmpty'][lineCount] = false
		SEC_CODES['DS'][lineCount] = {}
		SEC_CODES['calcAlgoValues'][lineCount] = {}
		SEC_CODES['dayATR'][lineCount] = 0
		SEC_CODES['dayDS'][lineCount] = nil
		SEC_CODES['dayATR_Period'][lineCount] = 29
		SEC_CODES['D_minus5'][lineCount] = 0
		SEC_CODES['lastTimeCalculated'][lineCount] = {}
		SEC_CODES['lastrealTimeCalculated'][lineCount] = {}
	

		lineCount = lineCount + 1
	end
	
    
    myLog("Intervals "..tostring(#INTERVALS["names"]))
    myLog("Sec codes "..tostring(#SEC_CODES['sec_codes']))
    CreateTable() -- ������� �������

    myLog("realTime functions "..tostring(#realtimeAlgorithms["functions"]))

    for i,v in ipairs(SEC_CODES['sec_codes']) do

        SEC_CODE_INDEX[i] = {}
        SEC_CODE = v
        CLASS_CODE =SEC_CODES['class_codes'][i]
        openedDS[i] = {}

        if getSecurityInfo(CLASS_CODE, SEC_CODE) == nil then
            isRun = false
            message("�� �������� �������� ������ �� �����������: "..SEC_CODE.."/"..tostring(CLASS_CODE))
            myLog("�� �������� �������� ������ �� �����������: "..SEC_CODE.."/"..tostring(CLASS_CODE))
            return false
        end

        SEC_PRICE_STEP = getParamEx(CLASS_CODE, SEC_CODE, "SEC_PRICE_STEP").param_value
        local status = getParamEx(CLASS_CODE,  SEC_CODE, "last").param_value
        local last_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"last").param_value)
        local open_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"prevprice").param_value)
        if last_price == 0 or last_price == nil then
            last_price = open_price
        end	
--	    SetCell(t_id, i, tableIndex["���� ��������"], tostring(open_price), open_price)  --i ������, 1 - �������, v - ��������	
        SetCell(t_id, i, tableIndex["������� ����"], tostring(last_price), last_price)  --i ������, 1 - �������, v - ��������	
		
        local highest_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"high").param_value)
        local lowest_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"low").param_value)
		
        local waprice = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"WAPRICE").param_value)
        SetCell(t_id, i, tableIndex["VWAP"], tostring(waprice), wapprice)  --i ������, 1 - �������, v - ��������

        local lastchange = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"lastchange").param_value)
        Str(i, tableIndex["%"], lastchange, 0, 0)  --i ������, 1 - �������, v - ��������


--        local delta = round(last_price-open_price,5)
--        SetCell(t_id, i, tableIndex["������"], tostring(delta), delta)  --i ������, 1 - �������, v - ��������
        local openCount, awg_price = GetTotalnet(CLASS_CODE, SEC_CODE)
        SetCell(t_id, i, tableIndex["�������"], tostring(openCount), openCount)  --i ������, 1 - �������, v - ��������
        if tonumber(awg_price)==0 then
            SetCell(t_id, i, tableIndex["�������"], '', 0)  --i ������, 1 - �������, v - ��������
            White(i, tableIndex["�������"])
        else
            Str(i, tableIndex["�������"], tonumber(awg_price), last_price)  --i ������, 1 - �������, v - ��������
        end
        --�������
        if showTradeCommands == true then
            SetCell(t_id, i,  tableIndex["<"], "-")  --i ������, 1 - �������, v - ��������
            SetCell(t_id, i, tableIndex["����� ������"], tostring(SEC_CODES['volume'][i]), SEC_CODES['volume'][i])  --i ������, 1 - �������, v - ��������
            SetCell(t_id, i, tableIndex[">"], "+")  --i ������, 1 - �������, v - ��������
            SetCell(t_id, i, tableIndex["������� BUY"], "BUY")  --i ������, 1 - �������, v - ��������
            Green(i, tableIndex["������� BUY"])
            SetCell(t_id, i, tableIndex["������� SELL"], "SELL")  --i ������, 1 - �������, v - ��������
            Red(i, tableIndex["������� SELL"])
            if openCount~=0 then
                Red(i, tableIndex["������� CLOSE"])
                SetCell(t_id, i, tableIndex["������� CLOSE"], "CLOSE")  --i ������, 0 - �������, v - ��������
            else
                White(i, tableIndex["������� CLOSE"])
                SetCell(t_id, i, tableIndex["������� CLOSE"], "")  --i ������, 0 - �������, v - ��������
            end
        end

        for kk,algo in pairs(realtimeAlgorithms["functions"]) do
            local initrf = realtimeAlgorithms["initAlgorithms"][kk]
            if initrf~=nil then
                initrf()
            end
            SEC_CODES['lastrealTimeCalculated'][i][kk] = g_previous_time
        end

        for cell,INTERVAL in pairs(INTERVALS["values"]) do

            --myLog(SEC_CODE.." interval "..tostring(INTERVAL))

            DS = DataSource(i,cell)
            SEC_CODES['DS'][i][cell] = DS
            SEC_CODES['lastTimeCalculated'][i][cell] = os.time()

            SEC_CODE_INDEX[i][cell] = DS:Size()
            --myLog("����� ������ ".. SEC_CODE..", ��������� "..INTERVALS["names"][cell].." "..tostring(SEC_CODE_INDEX[i][cell]))

            if status ~= nil and status ~= 0 then
                --interval algorithms
                local initf = INTERVALS["initAlgorithms"][cell]
                local calcf = INTERVALS["algorithms"][cell]
                local signalf = INTERVALS["signalAlgorithms"][cell]
                local settings = INTERVALS["settings"][cell]

				calcAlgoValue = {}
                if initf~=nil then
                    initf()
                end
                if calcf~=nil then
                    -- ������ ���������� ��� ������� ���������
                    calcAlgoValue = calcf(i, DS:Size(), settings, DS, INTERVAL)
                end

                SEC_CODES['calcAlgoValues'][i][cell] = calcAlgoValue[DS:Size()] or 0

                if signalf~=nil then
                    signalf(i, cell, settings, DS, false)
                elseif calcf~=nil then
                    up_downTest(i, cell, settings, DS, false)
                end
            end

            --ATR
            if INTERVAL == INTERVAL_D1 and isDayInterval == false then
                isDayInterval = true
                dayIntervalIndex = cell
            end

        end

        --ATR
        getATR(i, dayIntervalIndex)

        local lastATR = round(SEC_CODES['dayATR'][i], 5)
        if highest_price ==0 then highest_price = open_price end
        if lowest_price ==0 then lowest_price = open_price end
        local atrDelta = math.max(math.abs(highest_price - open_price), math.abs(open_price-lowest_price))
        if lastATR<math.abs(atrDelta) then
            Red(i, tableIndex["D ATR"])
        else
            White(i, tableIndex["D ATR"])
        end
        --ATR

        --W%
        local changeW = round((last_price - SEC_CODES['D_minus5'][i])*100/SEC_CODES['D_minus5'][i], 2)
        Str(i, tableIndex["%W"], changeW, 0, 0)
        --W%

    end

    myLog("================================================")
    myLog("Initialization finished")

end

function main() -- �������, ����������� �������� ����� ���������� � �������

    SetTableNotificationCallback(t_id, event_callback)
    SetTableNotificationCallback(tv_id, volume_event_callback)

    -- ���� �� ����
    while isRun do
        -- ���� ������ ���������� ���
        while isRun and GetServerDateTime().day == PrevDayNumber do sleep(100) end

        -- �������� ����� � �������� ��� ���� ��������� �����������
        local StartTime_sec = os.time(StrToTime(START_TIME))
        local StopTime_sec = os.time(StrToTime(STOP_TIME))

        -- ���� ������ ��������� ���
        while isRun and os.time(GetServerDateTime()) <= StartTime_sec do sleep(100) end

        --myLog(' GetServerDateTime() '..tostring(os.time(GetServerDateTime()))..' StartTime_sec '..tostring(StartTime_sec)..' StopTime_sec '..tostring(StopTime_sec))

        -- ���� ������ ���
        while isRun do -- ���� ����� ����������, ���� isRun == true

            -- �������� ����� �������
            local ServerDT = GetServerDateTime()
            local ServerDT_sec = os.time(ServerDT)

            -- ���� �������� ���� ����������, ������� � ���� �� ����
            if ServerDT_sec >= StopTime_sec then PrevDayNumber = ServerDT.day break end

            if PocketPopAll and not isPocketPopAll_done then
                if ServerDT_sec == os.time(StrToTime(PocketPopAll_time)) then
                    isPocketPopAll_done = true
                    package.path = ""
                    package.cpath = getScriptPath().. "\\".."QuikPocketPopAll.dll"
                    local tr = require "QuikPocketPopAll"
                    tr.Do()
                    tr = nil
                end
            end

            for i,v in ipairs(SEC_CODES['sec_codes']) do

                if isRun == false then break end

                SEC_CODE = v
                CLASS_CODE =SEC_CODES['class_codes'][i]

                -- �������� ��� ���� �����������, ��������� ����, �������� �������
                SEC_PRICE_STEP = getParamEx(CLASS_CODE, SEC_CODE, "SEC_PRICE_STEP").param_value
                local status = getParamEx(CLASS_CODE,  SEC_CODE, "last").param_value
                local last_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"last").param_value)
                local open_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"prevprice").param_value)
                local highest_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"high").param_value)
                local lowest_price = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"low").param_value)
                local waprice = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"WAPRICE").param_value)
                if last_price == 0 or last_price == nil then
                    last_price = open_price
                end
                local lp = GetCell(t_id, i, tableIndex["������� ����"]).value or last_price
                if lp < last_price then
                    Highlight(t_id, i, tableIndex["������� ����"], SeaGreen, QTABLE_DEFAULT_COLOR,1000)		-- ��������� ������, �������
                elseif lp > last_price then
                    Highlight(t_id, i, tableIndex["������� ����"], RosyBrown, QTABLE_DEFAULT_COLOR,1000)		-- ��������� ������ �������
                end
                SetCell(t_id, i, tableIndex["������� ����"], tostring(last_price), last_price)  --i ������, 1 - �������, v - ��������
                Str(i, tableIndex["VWAP"], waprice, last_price)
                local lastchange = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"lastchange").param_value)
                Str(i, tableIndex["%"], lastchange, 0, 0)  --i ������, 1 - �������, v - ��������
--                SetCell(t_id, i, tableIndex["���� ��������"], tostring(open_price), open_price)  --i ������, 1 - �������, v - ��������
--                local delta = round(last_price-open_price,5)
--                SetCell(t_id, i, tableIndex["������"], tostring(delta), delta)  --i ������, 1 - �������, v - ��������
                if IsWindowClosed(t_id) == false then
                    local awg_price = GetCell(t_id, i, tableIndex["�������"]).value or 0
                    if tonumber(awg_price)==0 then
                        White(i, tableIndex["�������"])
                    else
                        Str(i, tableIndex["�������"], tonumber(awg_price), last_price)
                    end
                end

                local current_time=ServerDT_sec

                --myLog(tostring(status))
                if status ~= nil and status ~= "0.000000" then

                    for kk,algo in pairs(realtimeAlgorithms["functions"]) do
                        local realf = realtimeAlgorithms["functions"][kk]
                        if realf~=nil then
                            local lastrealTimeCalculated = SEC_CODES['lastrealTimeCalculated'][i][kk] or current_time
                            local newrealTimeToCalculate = current_time
                            local realperiod = realtimeAlgorithms["recalculatePeriod"][kk] or 0
                            if realperiod ~= 0 then
                                newrealTimeToCalculate = lastrealTimeCalculated + realperiod
                                if current_time>newrealTimeToCalculate then
                                    --myLog(SEC_CODE.." realperiod "..tostring(realperiod).." lastrealTimeCalculated "..tostring(lastrealTimeCalculated))
                                    --myLog("newrealTimeToCalculate "..tostring(newrealTimeToCalculate))
                                    --myLog("current_time "..tostring(current_time))
                                    SEC_CODES['lastrealTimeCalculated'][i][kk] = current_time
                                    realf(i)
                                end
                            end
                        end
                    end

                    for cell,INTERVAL in pairs(INTERVALS["values"]) do

                        DS = SEC_CODES['DS'][i][cell]

                        local lastTimeCalculated = SEC_CODES['lastTimeCalculated'][i][cell]
                        local newTimeToCalculate = ServerDT_sec
                        local period = INTERVALS["recalculatePeriod"][cell] or 0
                        newTimeToCalculate = current_time
                        if period ~= 0 then
                            --newTimeToCalculate = lastTimeCalculated + 100*math.floor(period/60) + period%60
                            newTimeToCalculate = lastTimeCalculated + period*60
                        end

                        local timeCandle = DS:T(DS:Size())

                        --myLog(SEC_CODE.." - timeCandle "..tostring(os.time(timeCandle)).." - INTERVAL "..tostring(INTERVAL).." - period "..tostring(period))
                        --myLog(SEC_CODE.." - current_time "..tostring(current_time).." - lastTimeCalculated "..tostring(lastTimeCalculated).." - newTimeToCalculate "..tostring(newTimeToCalculate))
                        --myLog(SEC_CODE.." - current_time "..tostring(current_time))
                        --myLog(SEC_CODE.." - newtimeCandle "..tostring(os.time(timeCandle) + INTERVAL*60))
                        if SEC_CODE_INDEX[i][cell]<DS:Size() or current_time>newTimeToCalculate and current_time < (os.time(timeCandle) + INTERVAL*60) then --new candle

                            --myLog(SEC_CODE.." - ���������� ������ �� �������� "..INTERVALS["names"][cell])
                            SEC_CODES['lastTimeCalculated'][i][cell] = current_time

                            --interval algorithms
                            local initf = INTERVALS["initAlgorithms"][cell]
                            local calcf = INTERVALS["algorithms"][cell]
                            local signalf = INTERVALS["signalAlgorithms"][cell]
                            local settings = INTERVALS["settings"][cell]

							calcAlgoValue = {}
			                if initf~=nil then
			                    initf()
			                end
                            if calcf~=nil then
                                --myLog(SEC_CODE.." - INTERVAL "..tostring(INTERVAL))
                                calcAlgoValue = calcf(i, DS:Size(), settings, DS)
                            end
                            SEC_CODES['calcAlgoValues'][i][cell] = calcAlgoValue[DS:Size()] or 0

                            if signalf~=nil then
                                signalf(i, cell, settings, DS, true)
                            elseif calcf~=nil then
                                up_downTest(i, cell, settings, DS, true)
                            end

                            SEC_CODE_INDEX[i][cell] = DS:Size() --last candle
                        end

                    end
                end

                --ATR
                if SEC_CODES['D_minus5'][i]==0 or SEC_CODES['D_minus5'][i]==nil or SEC_CODES['dayATR'][i]==0 or SEC_CODES['dayATR'][i]==nil then
                    getATR(i, dayIntervalIndex)
                end
                local lastATR = round(SEC_CODES['dayATR'][i], 5)
                if highest_price ==0 then highest_price = open_price end
                if lowest_price ==0 then lowest_price = open_price end
                local atrDelta = math.max(math.abs(highest_price - open_price), math.abs(open_price-lowest_price))
                if lastATR<math.abs(atrDelta) then
                    Red(i, tableIndex["D ATR"])
                else
                    White(i, tableIndex["D ATR"])
                end
                --ATR

                --W%
                local changeW = round((last_price - SEC_CODES['D_minus5'][i])*100/SEC_CODES['D_minus5'][i], 2)
                Str(i, tableIndex["%W"], changeW, 0, 0)
                --W%
            end

            sleep(100)
        end
    end
end

-- ������� ���������� ���������� QUIK ��� ��������� �������
function OnStop()
    isRun = false
    myLog("Script Stoped")
    if t_id~= nil then
        DestroyTable(t_id)
    end
    if tv_id~= nil then
        DestroyTable(tv_id)
    end
    if thist_id~= nil then
        DestroyTable(thist_id)
    end
    calcAlgoValue = nil
    if logFile~=nil then logFile:close() end    -- ��������� ����
end
 -----------------------------
 -- ������ � �������� --
 -----------------------------

function CreateTable() -- ������� ������� �������

    t_id = AllocTable() -- �������� ��������� id ��� ��������
	local numCol = 0
    -- ��������� �������
    AddColumn(t_id, numCol, "����������", true, QTABLE_STRING_TYPE, 22)
    tableIndex["����������"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "%", true, QTABLE_DOUBLE_TYPE, 9)
    tableIndex["%"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "����", true, QTABLE_DOUBLE_TYPE, 13)
    tableIndex["������� ����"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "%W", true, QTABLE_DOUBLE_TYPE, 9)
    tableIndex["%W"] = numCol
	numCol = numCol+1
 --   AddColumn(t_id, numCol, "��������", true, QTABLE_DOUBLE_TYPE, 13)
--    tableIndex["���� ��������"] = numCol
--	numCol = numCol+1
    AddColumn(t_id, numCol, "VWAP", true, QTABLE_DOUBLE_TYPE, 13)
    tableIndex["VWAP"] = numCol
	numCol = numCol+1
--    AddColumn(t_id, numCol, "������", true, QTABLE_DOUBLE_TYPE, 13)
--    tableIndex["������"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "D ATR", true, QTABLE_DOUBLE_TYPE, 13)
    tableIndex["D ATR"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "���.", true, QTABLE_INT_TYPE, 7)
    tableIndex["�������"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "�������", true, QTABLE_DOUBLE_TYPE, 13)
    tableIndex["�������"] = numCol
	numCol = numCol+1
    AddColumn(t_id, numCol, "�������", true, QTABLE_DOUBLE_TYPE, 13)
    tableIndex["%�����"] = numCol
    numberOfFixedColumns = numCol
    numberOfVisibleColumns = 0
    local width = 0
    for i,v in ipairs(INTERVALS["names"]) do
        if INTERVALS["visible"][i] then
            numberOfVisibleColumns = numberOfVisibleColumns + 1
            AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns, v, true, QTABLE_DOUBLE_TYPE, INTERVALS["width"][i])
            tableIndex[i] = numberOfVisibleColumns+numberOfFixedColumns
            width = width + INTERVALS["width"][i]
        end
    end
    local columns = numberOfFixedColumns
    if showTradeCommands == true then
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+1, "����", true, QTABLE_DOUBLE_TYPE, 15) --Price
        tableIndex["���� ������"] = numberOfVisibleColumns+numberOfFixedColumns+1
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+2, "<", true, QTABLE_STRING_TYPE, 5) --Decrease volume
        tableIndex["<"] = numberOfVisibleColumns+numberOfFixedColumns+2
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+3, "Vol", true, QTABLE_INT_TYPE, 7) --Volume
        tableIndex["����� ������"] = numberOfVisibleColumns+numberOfFixedColumns+3
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+4, ">", true, QTABLE_STRING_TYPE, 5) --Increase volume
        tableIndex[">"] = numberOfVisibleColumns+numberOfFixedColumns+4
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+5, "BUY", true, QTABLE_STRING_TYPE, 10) --BUY
        tableIndex["������� BUY"] = numberOfVisibleColumns+numberOfFixedColumns+5
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+6, "SELL", true, QTABLE_STRING_TYPE, 10) --SELL
        tableIndex["������� SELL"] = numberOfVisibleColumns+numberOfFixedColumns+6
        AddColumn(t_id, numberOfVisibleColumns+numberOfFixedColumns+7, "CLOSE", true, QTABLE_STRING_TYPE, 10) --CLOSE ALL
        tableIndex["������� CLOSE"] = numberOfVisibleColumns+numberOfFixedColumns+7
        columns = columns + 2.3
    end
    t = CreateWindow(t_id) -- ������� �������
    SetWindowCaption(t_id, "Monitor") -- ������������� ���������
    SetWindowPos(t_id, 90, 60, 87*columns + width*5.8, #SEC_CODES['sec_codes']*17.2) -- ������ ��������� � ������� ���� �������

    -- ��������� ������
    for i,v in ipairs(SEC_CODES['names']) do
        InsertRow(t_id, i)
        SetCell(t_id, i, tableIndex["����������"], v)  --i ������, 0 - �������, v - ��������
    end

    tv_id = AllocTable() -- ������� ����� ��������

    thist_id = AllocTable() --������� ������� ������

    -- ��������� �������
    AddColumn(thist_id, 0, "����������", true, QTABLE_STRING_TYPE, 20)
    AddColumn(thist_id, 1, "����� ������", true, QTABLE_INT_TYPE, 20)
    AddColumn(thist_id, 2, "���� ������", true, QTABLE_STRING_TYPE, 29)
    AddColumn(thist_id, 3, "���", true, QTABLE_STRING_TYPE, 15)
    AddColumn(thist_id, 4, "����������", true, QTABLE_INT_TYPE, 17)
    AddColumn(thist_id, 5, "����", true, QTABLE_DOUBLE_TYPE, 17)
    AddColumn(thist_id, 6, "�����������", true, QTABLE_STRING_TYPE, 130)

end

function Str(str, num, value, testvalue, dir) -- ������� ������� � ���������� ������ � �������
    if dir == nil then dir = 1 end
    SetCell(t_id, str, num, tostring(value), value) -- ������� �������� � �������: ������, ��������, ��������
    if (value < testvalue and dir == 1) or (value > testvalue and dir == 0) then Green(str, num) elseif value == testvalue then Gray(str, num) else Red(str, num) end -- ���������� ������ � ����������� �� �������� �������
end

 -----------------------------
 -- ������� �� ��������� �����/����� ������� --
 -----------------------------

function Green(Line, Col) -- �������
   if Col == nil then Col = QTABLE_NO_INDEX end -- ���� ������ ������� �� ������, ���������� ��� ������
   SetColor(t_id, Line, Col, RGB(165,227,128), RGB(0,0,0), RGB(165,227,128), RGB(0,0,0))
end

function Gray(Line, Col) -- �����
   if Col == nil then Col = QTABLE_NO_INDEX end -- ���� ������ ������� �� ������, ���������� ��� ������
   SetColor(t_id, Line, Col, RGB(200,200,200), RGB(0,0,0), RGB(200,200,200), RGB(0,0,0))
end

function Red(Line, Col) -- �������
   if Col == nil then Col = QTABLE_NO_INDEX end -- ���� ������ ������� �� ������, ���������� ��� ������
   SetColor(t_id, Line, Col, RGB(255,168,164), RGB(0,0,0), RGB(255,168,164), RGB(0,0,0))
end

function White(Line, Col) -- �����
   if Col == nil then Col = QTABLE_NO_INDEX end -- ���� ������ ������� �� ������, ���������� ��� ������
   SetColor(t_id, Line, Col, RGB(255,255,255), RGB(0,0,0), RGB(255,255,255), RGB(0,0,0))
end

function cellSetColor(Line, Col, Color, textColor)
   if Col == nil then Col = QTABLE_NO_INDEX end -- ���� ������ ������� �� ������, ���������� ��� ������
   if Color == nil then Color =  RGB(255,255,255) end -- ���� ���� �� ������, ���������� � �����
   if textColor == nil then textColor = RGB(0,0,0) end -- ���� ���� �� ������, ���� ������
   SetColor(t_id, Line, Col, Color, textColor, Color, textColor)
end

-----------------------------
-- ��������� ������ ������� --
-----------------------------
function volume_event_callback(tv_id, msg, par1, par2)
    if par1 == -1 then
        return
    end
    if msg == QTABLE_CHAR then
        if tostring(par2) == "8" then
            local newPrice = string.sub(GetCell(tv_id, par1, 0).image, 1, string.len(GetCell(tv_id, par1, 0).image)-1)
            SetCell(tv_id, par1, 0, tostring(newPrice))
            SetCell(t_id, tstr, tcell, GetCell(tv_id, par1, 0).image, tonumber(GetCell(tv_id, par1, 0).image))
        else
           local inpChar = string.char(par2)
           local newPrice = GetCell(tv_id, par1, 0).image..string.char(par2)
           SetCell(tv_id, par1, 0, tostring(newPrice))
           SetCell(t_id, tstr, tcell, GetCell(tv_id, par1, 0).image, tonumber(GetCell(tv_id, par1, 0).image))
       end
    end
end

function event_callback(t_id, msg, par1, par2)

    if msg == QTABLE_LBUTTONDBLCLK and showTradeCommands == true then

        if par2 == tableIndex["����������"] then --������� ������
           createDealsTable(par1)
        end
        if par2 == tableIndex["������� ����"] or par2 == tableIndex["�������"] or (par2 > numberOfFixedColumns and par2 <= numberOfVisibleColumns+numberOfFixedColumns) then --����� ����
            local TRADE_SEC_CODE = SEC_CODES['sec_codes'][par1]
            local TRADE_CLASS_CODE = SEC_CODES['class_codes'][par1]
            local newPrice = GetCorrectPrice(GetCell(t_id, par1, par2).value, TRADE_CLASS_CODE, TRADE_SEC_CODE)
            local stringPrice = string.gsub(tostring(newPrice),',', '.')
            local numberPrice = tonumber(stringPrice)
             if numberPrice~=nil and numberPrice~=0 then
                SetCell(t_id, par1, tableIndex["���� ������"], stringPrice, numberPrice)  --i ������, 1 - �������, v - ��������
            end
        end
        if par2 == tableIndex["���� ������"] and IsWindowClosed(tv_id) then --������ ����
            tstr = par1
            tcell = par2
            AddColumn(tv_id, 0, "��������", true, QTABLE_DOUBLE_TYPE, 25)
            tv = CreateWindow(tv_id)
            SetWindowCaption(tv_id, "������� ����")
            SetWindowPos(tv_id, 290, 260, 250, 100)
            InsertRow(tv_id, 1)
            SetCell(tv_id, 1, 0, GetCell(t_id, par1, tableIndex["���� ������"]).image, GetCell(t_id, par1, tableIndex["���� ������"]).value)  --i ������, 0 - �������, v - ��������
        end
        if par2 == tableIndex["����� ������"] and IsWindowClosed(tv_id) then --������ �����
            tstr = par1
            tcell = par2
            AddColumn(tv_id, 0, "��������", true, QTABLE_INT_TYPE, 25)
            tv = CreateWindow(tv_id)
            SetWindowCaption(tv_id, "������� �����")
            SetWindowPos(tv_id, 290, 260, 250, 100)
            InsertRow(tv_id, 1)
            SetCell(tv_id, 1, 0, GetCell(t_id, par1, tableIndex["����� ������"]).image, GetCell(t_id, par1, tableIndex["����� ������"]).value)  --i ������, 0 - �������, v - ��������
        end
        if par2 == tableIndex["������� CLOSE"] then -- All Close
            local TRADE_SEC_NAME = SEC_CODES['names'][par1]
            local TRADE_SEC_CODE = SEC_CODES['sec_codes'][par1]
            local TRADE_CLASS_CODE = SEC_CODES['class_codes'][par1]
            local QTY_LOTS = GetCell(t_id, par1, tableIndex["�������"]).value
            if QTY_LOTS == 0 or QTY_LOTS==nil then
                message("����������� ������ �����!!!")
                return
            end
            if QTY_LOTS ~=0 then
                local CurrentDirect = 'SELL'
                message(TRADE_SEC_NAME.." �������� ���� �������, �����: "..tostring(QTY_LOTS)..", �� �����")
                MakeTransaction(CurrentDirect, QTY_LOTS, 0, TRADE_CLASS_CODE, TRADE_SEC_CODE)
            end
        end
        if par2 == tableIndex["������� BUY"] then --BUY volume
            local TRADE_SEC_NAME = SEC_CODES['names'][par1]
            local TRADE_SEC_CODE = SEC_CODES['sec_codes'][par1]
            local TRADE_CLASS_CODE = SEC_CODES['class_codes'][par1]
            local CurrentDirect = 'BUY'
            local QTY_LOTS = GetCell(t_id, par1, tableIndex["����� ������"]).value
            if QTY_LOTS == 0 or QTY_LOTS==nil then
                message("����������� ������ �����!!!")
                return
            end
            local TRADE_PRICE = GetCell(t_id, par1, tableIndex["���� ������"]).value
            local checkString = GetCell(t_id, par1, tableIndex["���� ������"]).image
            if (TRADE_PRICE==nil or TRADE_PRICE==0) and string.len(checkString) ~= 0 then
                message("����������� ������� ����: "..tostring(TRADE_PRICE))
                return
            end
            message(TRADE_SEC_NAME.." �������, �����: "..tostring(QTY_LOTS)..", ����: "..tostring(TRADE_PRICE))
            MakeTransaction(CurrentDirect, QTY_LOTS, TRADE_PRICE, TRADE_CLASS_CODE, TRADE_SEC_CODE)
        end
        if par2 == tableIndex["������� SELL"] then --SELL volume
            local TRADE_SEC_NAME = SEC_CODES['names'][par1]
            local TRADE_SEC_CODE = SEC_CODES['sec_codes'][par1]
            local TRADE_CLASS_CODE = SEC_CODES['class_codes'][par1]
            local CurrentDirect = 'SELL'
            local QTY_LOTS = GetCell(t_id, par1, tableIndex["����� ������"]).value
            if QTY_LOTS == 0 or QTY_LOTS==nil then
                message("����������� ������ �����!!!")
                return
            end
            local TRADE_PRICE = GetCell(t_id, par1, tableIndex["���� ������"]).value
            local checkString = GetCell(t_id, par1, tableIndex["���� ������"]).image
            if (TRADE_PRICE==nil or TRADE_PRICE==0) and string.len(checkString) ~= 0 then
                message("����������� ������� ����: "..tostring(TRADE_PRICE))
                return
            end
            message(TRADE_SEC_NAME.." �������, �����: "..tostring(QTY_LOTS)..", ����: "..tostring(TRADE_PRICE))
            MakeTransaction(CurrentDirect, QTY_LOTS, TRADE_PRICE, TRADE_CLASS_CODE, TRADE_SEC_CODE)
        end
        if par2 ==  tableIndex["<"] then
            local newVolume = GetCell(t_id, par1, tableIndex["����� ������"]).value - SEC_CODES['volume'][par1]
            SetCell(t_id, par1, tableIndex["����� ������"], tostring(newVolume), newVolume)  --i ������, 1 - �������, v - ��������
        end
        if par2 == tableIndex[">"] then
            local newVolume = GetCell(t_id, par1, tableIndex["����� ������"]).value + SEC_CODES['volume'][par1]
            SetCell(t_id, par1, tableIndex["����� ������"], tostring(newVolume), newVolume)  --i ������, 1 - �������, v - ��������
        end
    end
    if msg == QTABLE_CHAR and showTradeCommands == true then
        --message("������� "..tostring(par2))
        if tostring(par2) == "8" then --BackSpace
           SetCell(t_id, par1, tableIndex["���� ������"], "")
        end
        if tostring(par2) == "68" or tostring(par2) == "194" then --Shift+D
            local TRADE_SEC_CODE = SEC_CODES['sec_codes'][par1]
            local TRADE_SEC_NAME = SEC_CODES['names'][par1]
            local TRADE_CLASS_CODE = SEC_CODES['class_codes'][par1]
            message("������� ��� ������ "..TRADE_SEC_NAME)
            KillAllOrders("orders", TRADE_CLASS_CODE, TRADE_SEC_CODE)
        end
        if tostring(par2) == "83" or tostring(par2) == "219" then --Shift+S
            local TRADE_SEC_CODE = SEC_CODES['sec_codes'][par1]
            local TRADE_SEC_NAME = SEC_CODES['names'][par1]
            local TRADE_CLASS_CODE = SEC_CODES['class_codes'][par1]
            message("������� ��� ���� ������ "..TRADE_SEC_NAME)
            KillAllOrders("stop_orders", TRADE_CLASS_CODE, TRADE_SEC_CODE)
        end
        if tostring(par2) == "65" or tostring(par2) == "212" then --sound --Shift+A
            local curSound = SEC_CODES['isPlaySound'][par1]
            if curSound == 1 then
                SEC_CODES['isPlaySound'][par1] = 0
                message("��������� ���� �  "..SEC_CODES['names'][par1])
            else
                SEC_CODES['isPlaySound'][par1] = 1
                message("�������� ���� � "..SEC_CODES['names'][par1])
            end
        end
    end
    if (msg==QTABLE_CLOSE) then --�������� ����
        isRun = false
    end
end
-----------------------------
-- ��������� ������ ������� --
-----------------------------

--�������� ������� ������ ������
function createDealsTable(iSec)

    Clear(thist_id)

    local secCode = SEC_CODES['sec_codes'][iSec]
    local classCode = SEC_CODES['class_codes'][iSec]
    local secTradesFilePath = TradesFilePath..ACCOUNT.."\\"..secCode..".csv"

    TradesFile = io.open(secTradesFilePath,"r")
    if TradesFile ~= nil then

        if IsWindowClosed(thist_id) then
            thist = CreateWindow(thist_id)
            SetWindowCaption(thist_id, "������")
            SetWindowPos(thist_id, 290, 260, 1400, 800)
        end

        TradesFile:seek('set',0)

        local tradeTable = {}

        -- ���������� ������ �����, ��������� ���������� � ������ ������
        local Count = 0 -- ������� �����
        for line in TradesFile:lines() do

            Count = Count + 1
            if Count > 1 and line ~= "" then

                InsertRow(thist_id, Count - 1)
                SetCell(thist_id, Count - 1, 0, SEC_CODES['names'][iSec])


                local i = 0 -- ������� ��������� ������
                local dateDeal = ''
                local timeDeal = ''
                local prefix = 1

                for str in line:gmatch("[^;^\n]+") do
                    i = i + 1
                    if i == 3 then
                        SetCell(thist_id, Count - 1, 1, str, tonumber(str))
                    elseif i == 4 then
                        dateDeal = string.sub(str, 1, 4).."/"..string.sub(str, 5, 6).."/"..string.sub(str, 7, 8)
                    elseif i == 5 then
                        timeDeal = string.sub(str, 1, 2)..":"..string.sub(str, 3, 4)..":"..string.sub(str, 5, 6)
                        SetCell(thist_id, Count - 1, 2, dateDeal.." "..timeDeal)
                    elseif i == 6 then
                        if str == "B" then
                            SetCell(thist_id, Count - 1, 3, "�������")
                            prefix = 1
                            --SetColor(thist_id, Count - 1, QTABLE_NO_INDEX, RGB(165,227,128), RGB(0,0,0), RGB(165,227,128), RGB(0,0,0))
                        else
                            SetCell(thist_id, Count - 1, 3, "�������")
                            prefix = -1
                        end
                    elseif i == 7 then
                        SetCell(thist_id, Count - 1, 4, str, tonumber(str))
                        tradeTable[Count] = prefix*tonumber(str)
                    elseif i == 8 then
                        SetCell(thist_id, Count - 1, 5, str, tonumber(str))
                    elseif i == 9 then
                        SetCell(thist_id, Count - 1, 6, str)
                    end
                end

            end

        end

        local netCount = GetTotalnet(classCode, secCode)
        local netSell = 0
        if netCount > 0 then
            for tN=#tradeTable,1,-1 do

                if netCount == 0 then
                    break
                end
                if tradeTable[tN] ~= nil then
                    if tradeTable[tN] < 0 then
                        netSell = netSell - tradeTable[tN]
                    end
                    if tradeTable[tN] > 0 and netSell ==0 then
                        SetColor(thist_id, tN - 1, QTABLE_NO_INDEX, RGB(165,227,128), RGB(0,0,0), RGB(165,227,128), RGB(0,0,0))
                        netCount = math.max(netCount - tradeTable[tN], 0)
                        netSell = math.max(netSell - tradeTable[tN], 0)
                    end
                    if tradeTable[tN] > 0 and netSell ~=0 then
                        netSell = math.max(netSell - tradeTable[tN], 0)
                    end
                end

            end
        end

    else
        message("������ �� ����������� ���")
    end
end

-------------------------------------
--��������--
-------------------------------------
-- ������� ���������� ���������� QUIK ��� ��������� ������ �� ���������� ������������
function OnTransReply(trans_reply)
    -- ���� ��������� ���������� �� ������� ����������
    if trans_reply.trans_id == trans_id then
        -- �������� ������ � ���������� ����������
        trans_Status = trans_reply.status
        -- �������� ��������� � ���������� ����������
        trans_result_msg  = trans_reply.result_msg

        if Status == 2 then
            message("������ ��� �������� ���������� � �������� �������. ��� ��� ����������� ����������� ����� ���������� �����, �������� ���������� �� ������������")
            myLog("������ ��� �������� ���������� � �������� �������. ��� ��� ����������� ����������� ����� ���������� �����, �������� ���������� �� ������������")
        end

        if trans_Status > 3 then
            if trans_Status == 4 then messageText = "���������� �� ���������" end
            if trans_Status == 5 then messageText = "���������� �� ������ �������� ������� QUIK" end
            if trans_Status == 6 then messageText = "���������� �� ������ �������� ������� ������� QUIK" end
            if trans_Status == 7 then messageText = "���������� �� �������������� �������� ��������" end
            message('NRTR monitor: ���������� ������� ������: '..messageText)
            myLog('NRTR monitor: ���������� ������� ������: '..messageText)
        end

        myLog("OnTransReply "..tostring(trans_id).." "..trans_result_msg)
    end

    --[[
    for i=0,getNumberOf('orders')-1 do
        local order = getItem('orders', i)
        myLog("trans_id = " .. tostring(order["trans_id"]).." order: num = " .. tostring(order["order_num"]) .." qty=" ..tostring(order["qty"]).." value= "..tostring(order["value"]).." brokerref= "..tostring(order["brokerref"]))
     end
    ]]--
end

function MakeTransaction(CurrentDirect, QTY_LOTS, TRADE_PRICE, TRADE_CLASS_CODE, TRADE_SEC_CODE)
    return Trade(CurrentDirect, QTY_LOTS, TRADE_PRICE, TRADE_CLASS_CODE ,TRADE_SEC_CODE)
end

-- ��������� ������ ���������� ���� (Type) ["BUY", ��� "SELL"]
function Trade(Type, qnt, TRADE_PRICE, TRADE_CLASS_CODE, TRADE_SEC_CODE)
    --�������� ID ����������
    trans_id = trans_id + 1
    if TRADE_PRICE == nil then
        TRADE_PRICE = 0
    end

    local TRADE_TYPE = 'M'-- �� ����� (MARKET)
    if TRADE_PRICE ~= 0 then
        TRADE_TYPE = 'L'
    end

    local Operation = ''
    --������������� ���� � ��������, � ����������� �� ���� ������ � �� ������ �����������
    TRADE_SEC_PRICE_STEP = tonumber(getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, "SEC_PRICE_STEP").param_value)
    if Type == 'BUY' then
        Operation = 'B'
        if TRADE_PRICE == 0 and TRADE_CLASS_CODE ~= 'QJSIM' and TRADE_CLASS_CODE ~= 'TQBR' then
            TRADE_PRICE = getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, 'offer').param_value + 10*TRADE_SEC_PRICE_STEP
        end -- �� ����, ���������� �� 10 ���. ����� ����
    else
        Operation = 'S'
        if TRADE_PRICE == 0 and TRADE_CLASS_CODE ~= 'QJSIM' and TRADE_CLASS_CODE ~= 'TQBR' then
            TRADE_PRICE = getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, 'bid').param_value - 10*TRADE_SEC_PRICE_STEP
        end -- �� ����, ���������� �� 10 ���. ����� ����
    end
    -- ��������� ��������� ��� �������� ����������
    --TRADE_PRICE = GetCorrectPrice(TRADE_PRICE, TRADE_CLASS_CODE, TRADE_SEC_CODE)
    myLog("script Monitor: "..TRADE_TYPE.." Transaction "..Type..' '..TRADE_PRICE)

    local Transaction={
       ['TRANS_ID']   = tostring(trans_id),
       ['ACTION']     = 'NEW_ORDER',
       ['CLASSCODE']  = TRADE_CLASS_CODE,
       ['SECCODE']    = TRADE_SEC_CODE,
       ['CLIENT_CODE'] = CLIENT_CODE,
       ['OPERATION']  = Operation, -- �������� ("B" - buy, ��� "S" - sell)
       ['TYPE']       = TRADE_TYPE,
       ['QUANTITY']   = tostring(qnt), -- ����������
       ['ACCOUNT']    = ACCOUNT,
       ['PRICE']      = tostring(TRADE_PRICE),
       ['COMMENT']    = 'script Monitor' -- ����������� � ����������, ������� ����� ����� � �����������, ������� � �������
    }
    -- ���������� ����������
    local res = sendTransaction(Transaction)
    if string.len(res) ~= 0 then
        message('Script monitor: ���������� ������� ������: '..res)
        myLog('Script monitor: ���������� ������� ������: '..res)
        return false
     end

     return true

end

--TAKE_PROFIT -  ����������� ����� ���� �������
--STOP_LOSS - ����������� ����� ���� ����-�����
--TRADE_PRICE - ������� ����, �� ������� ����������� ����-������
--TakeProfitPrice - ���������� ����, ��� ���������

function SL_TP(TRADE_PRICE, TakeProfitPrice, Type, STOP_LOSS, TAKE_PROFIT ,TRADE_CLASS_CODE, TRADE_SEC_CODE)
    -- ID ����������
    trans_id = trans_id + 1

     -- ������� ����������� ��� ������
     local operation = ""
     local price = "0" -- ����, �� ������� ���������� ������ ��� ������������ ����-����� (��� �������� ������ �� ������ ������ ���� 0)
     local stopprice = "" -- ���� ����-�������
     local stopprice2 = "" -- ���� ����-�����
     local market = "YES" -- ����� ������������ �����, ��� �����, ������ ��������� �� �������� ����
     local direction
     TRADE_SEC_PRICE_STEP = tonumber(getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, "SEC_PRICE_STEP").param_value)

  -- ���� ������ BUY, �� ����������� ����-����� � ����-������� SELL, ����� ����������� ����-����� � ����-������� BUY
     if Type == 'BUY' then
         operation = "S" -- ����-������ � ����-���� �� �������(����� ������� BUY, ����� ������� SELL)
         direction = "5" -- �������������� ����-����. �5� - ������ ��� �����
       -- ���� �� �����
       if TRADE_CLASS_CODE ~= 'QJSIM' and TRADE_CLASS_CODE ~= 'TQBR' then
          price = tostring(math.floor(getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, 'PRICEMIN').param_value)) -- ���� ������������ ������ ����� ������������� ����� ���������� ���������, ����� �� �������������
          market = "YES"  -- ����� ������������ �����, ��� �����, ������ ��������� �� �� �������� ����
       end
         if (TakeProfitPrice or 0) == 0 then
             stopprice	= tostring(TRADE_PRICE + TAKE_PROFIT*TRADE_SEC_PRICE_STEP) -- ������� ����, ����� ������������ ����-������
             TakeProfitPrice = stopprice
         else
             stopprice = TakeProfitPrice + math.floor(STOP_LOSS*TRADE_SEC_PRICE_STEP/2)    -- ������� �������� ����-������
         end
         stopprice2	= tostring(TRADE_PRICE - STOP_LOSS*TRADE_SEC_PRICE_STEP) -- ������� ����, ����� ������������ ����-����
         price = stopprice2 - 2*TRADE_SEC_PRICE_STEP
     else -- ������ SELL
         operation = "B" -- ����-������ � ����-���� �� �������(����� ������� SELL, ����� ������� BUY)
         direction = "4" -- �������������� ����-����. �4� - ������ ��� �����
       -- ���� �� �����
         if TRADE_CLASS_CODE ~= 'QJSIM' and TRADE_CLASS_CODE ~= 'TQBR' then
          price = tostring(math.floor(getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, 'PRICEMAX').param_value)) -- ���� ������������ ������ ����� ������������� ����� ����������� ���������, ����� �� �������������
          market = "YES"  -- ����� ������������ �����, ��� �����, ������ ��������� �� �� �������� ����
       end
         if (TakeProfitPrice or 0) == 0 then
             stopprice	= tostring(TRADE_PRICE - TAKE_PROFIT*TRADE_SEC_PRICE_STEP) -- ������� ����, ����� ������������ ����-������
             TakeProfitPrice = stopprice
         else
             stopprice = TakeProfitPrice - math.floor(STOP_LOSS*TRADE_SEC_PRICE_STEP/2)  -- ������� �������� ����-������
         end
         stopprice2	= tostring(TRADE_PRICE + STOP_LOSS*TRADE_SEC_PRICE_STEP) -- ������� ����, ����� ������������ ����-����
         price = stopprice2 + 2*TRADE_SEC_PRICE_STEP
     end
     -- ��������� ��������� ��� �������� ���������� �� ����-���� � ����-������
      myLog('Script monitor: ��������� ����-������: '..stopprice..' � ����-����: '..stopprice2)

     local Transaction = {
         ["ACTION"]              = "NEW_STOP_ORDER", -- ��� ������
         ["TRANS_ID"]            = tostring(trans_id),
         ["CLASSCODE"]           = TRADE_CLASS_CODE,
         ["SECCODE"]             = TRADE_SEC_CODE,
         ["ACCOUNT"]             = ACCOUNT,
         ['CLIENT_CODE'] = CLIENT_CODE, -- ����������� � ����������, ������� ����� ����� � �����������, ������� � �������
         ["OPERATION"]           = operation, -- �������� ("B" - �������(BUY), "S" - �������(SELL))
         ["QUANTITY"]            = tostring(QTY_LOTS), -- ���������� � �����
         ["PRICE"]               = GetCorrectPrice(price), -- ����, �� ������� ���������� ������ ��� ������������ ����-����� (��� �������� ������ �� ������ ������ ���� 0)
         ["STOPPRICE"]           = GetCorrectPrice(stopprice), -- ���� ����-�������
         ["STOP_ORDER_KIND"]     = "TAKE_PROFIT_AND_STOP_LIMIT_ORDER", -- ��� ����-������
         ["EXPIRY_DATE"]         = "GTC", -- ���� �������� ����-������ ("GTC" � �� ������,"TODAY" - �� ��������� ������� �������� ������, ���� � ������� "������")
       -- "OFFSET" - (������)���� ���� �������� ����-������� � ���� ������ � �������,
       -- �� ����-������ ��������� ������ ����� ���� �������� ������� �� 2 ���� ���� �����,
       -- ��� ����� ������������ ��������� �������
         ["OFFSET"]              = tostring(2*TRADE_SEC_PRICE_STEP),
         ["OFFSET_UNITS"]        = "PRICE_UNITS", -- ������� ��������� ������� ("PRICE_UNITS" - ��� ����, ��� "PERCENTS" - ��������)
       -- "SPREAD" - ����� ��������� ����-������, ���������� ������ �� ���� ���� ������� �� 100 ����� ����,
       -- ������� ������������� �������������� �� ������� ������ ����,
       -- �� ��, ��� ���� ����������� ����, ������ �� ���������������,
       -- �����, ������ ����� ������ �� ��������� (������ �� �������� ����� ����������, �� ���� � ���� ������� �� ��� ���������)
         ["SPREAD"]              = tostring(100*TRADE_SEC_PRICE_STEP),
         ["SPREAD_UNITS"]        = "PRICE_UNITS", -- ������� ��������� ��������� ������ ("PRICE_UNITS" - ��� ����, ��� "PERCENTS" - ��������)
       -- "MARKET_TAKE_PROFIT" = ("YES", ��� "NO") ������ �� ���������� ������ �� �������� ���� ��� ������������ ����-�������.
       -- ��� ����� FORTS �������� ������, ��� �������, ���������,
       -- ��� �������������� ������ �� FORTS ����� ��������� �������� ������ ����, ����� ��� ��������� ����� ��, ��� ��������
         ["MARKET_TAKE_PROFIT"]  = market,
         ["STOPPRICE2"]          = GetCorrectPrice(stopprice2), -- ���� ����-�����
         ["IS_ACTIVE_IN_TIME"]   = "NO",
       -- "MARKET_TAKE_PROFIT" = ("YES", ��� "NO") ������ �� ���������� ������ �� �������� ���� ��� ������������ ����-�����.
       -- ��� ����� FORTS �������� ������, ��� �������, ���������,
       -- ��� �������������� ������ �� FORTS ����� ��������� �������� ������ ����, ����� ��� ��������� ����� ��, ��� ��������
         ["MARKET_STOP_LIMIT"]   = market,
         ['CONDITION'] = direction, -- �������������� ����-����. ��������� ��������: �4� - ������ ��� �����, �5� � ������ ��� �����
         ["COMMENT"]             = "Script monitor ����-������ � ����-����"
     }
    -- ���������� ���������� �� ��������� ����-������ � ����-����
    local res = sendTransaction(Transaction)
    if string.len(res) ~= 0 then
       message('Script monitor: ��������� ����-������ � ����-���� �� �������!\n������: '..res)
       myLog('Script monitor: ��������� ����-������ � ����-���� �� �������!\n������: '..res)
       return false
    else
       -- ������� ���������
       message('Script monitor: ���������� ������ ����-������ � ����-����: '..trans_id)
      myLog('Script monitor: ���������� ������ ����-������ � ����-����: '..trans_id)
      return true
    end

end

--ordtable = "stop_orders"
--ordtable = "orders"
function KillAllOrders(ordtable, TRADE_CLASS_CODE, TRADE_SEC_CODE)
    function myFind(C,S,F)
       return (C == TRADE_CLASS_CODE) and (S == TRADE_SEC_CODE) and (bit.band(F, 0x1) ~= 0)
    end
    local res=1
    local action = "KILL_ORDER"
    local order_key = "ORDER_KEY"
    if ordtable == "stop_orders" then
        action = "KILL_STOP_ORDER"
        order_key = "STOP_ORDER_KEY"
    end
    local orders = SearchItems(ordtable, 0, getNumberOf(ordtable)-1, myFind, "class_code,sec_code,flags")
    if (orders ~= nil) and (#orders > 0) then

        for i=1,#orders do
         -- �������� ID ��� ��������� ����������
        trans_id = trans_id + 1
        -- ��������� ��������� ��� �������� ���������� �� ������ ����-������
         local Transaction = {
             ["ACTION"]              = action, -- ��� ������
             ["TRANS_ID"]            = tostring(trans_id),
             ["CLASSCODE"]           = TRADE_CLASS_CODE,
             ["SECCODE"]             = TRADE_SEC_CODE,
             ["ACCOUNT"]             = ACCOUNT,
             ['CLIENT_CODE'] = CLIENT_CODE, -- ����������� � ����������, ������� ����� ����� � �����������, ������� � �������
             [order_key]      = tostring(getItem(ordtable,orders[i]).order_num) -- ����� ������, ��������� �� �������� �������
         }
            -- ���������� ����������
            local Res = sendTransaction(Transaction)
            -- ���� ��� �������� ���������� �������� ������
            if string.len(Res) ~= 0 then
               -- ������� ������
               message('������ ������ ������: '..Res)
               myLog('������ ������ ������: '..Res)
               return false
            end

           local order = getItem(ordtable, orders[i])
           -- ���� ����-������ �� �������
           myLog('������� ������: '..order.sec_code..' number: '..tostring(order.order_num))
           if not bit.test(order.flags, 0) then
              -- ���� ������ ������ �����������
              if not bit.test(order.flags, 1) then
                 return true
              else
                 message('�������� ����������� ������ ��� ������ ������ '..tostring(order.order_num))
                 myLog('�������� ����������� ������ ��� ������ ������ '..tostring(order.order_num))
                 return false
              end
           end
        end
    else
        message("�� ������� �������� ������ "..TRADE_SEC_CODE)
        myLog("�� ������� �������� ������ "..TRADE_SEC_CODE)
    end

   return true
end

-- ��������� ������� ����-������ �� ��� ������
-- ���������� ������� ����-����� ��� nil
function getStopOrderByNumber(stop_order_number,from,to)
    local index_table = SearchItems("stop_orders",
                                            from or 0,
                                            to or getNumberOf("stop_orders")-1,
                                            function(t)
                                                return t.order_num == stop_order_number
                                            end)
    if index_table then
       return getItem("stop_orders",index_table[1])
    end
end

-- ��������� ������� ����-������ �� ������ ����������� �� ������
-- ���������� ������� ����-������ ��� nil
function getStopOrderByOrderNumber(order_number,from,to)
    local index_table = SearchItems("stop_orders",
                                               from or 0,
                                               to or getNumberOf("stop_orders")-1,
                                               function(t)
                                                   return t.linkedorder == order_number
                                               end)
    if index_table then
       return getItem("stop_orders",index_table[1])
    end
end
-------------------------------------
--��������--
-------------------------------------

-----------------------------
-- �������� --
-----------------------------
function up_downTest(i, cell, settings, DS, signal)

    --local testvalue = tonumber(getParamEx(CLASS_CODE,SEC_CODE,"last").param_value) or 0
    local index = DS:Size()
	local testvalue = GetCell(t_id, i, tableIndex["������� ����"]).value
    local price_step = tonumber(getParamEx(CLASS_CODE, SEC_CODE, "SEC_PRICE_STEP").param_value) or 0
    local scale = getSecurityInfo(CLASS_CODE, SEC_CODE).scale
    local signaltestvalue1 = calcAlgoValue[index-1] or 0
    local signaltestvalue2 = calcAlgoValue[index-2] or 0
    local testZone = settings.testZone or 10

    if calcAlgoValue[index] == nil or index == 0 then return end
    local calcVal = round(calcAlgoValue[index] or 0, scale)

    local testSignalZone = price_step*testZone
    local downTestZone = calcVal-testSignalZone
    local upTestZone = calcVal+testSignalZone

    if INTERVALS["visible"][cell] then
        local Color = RGB(255, 255, 255)
        if testvalue > downTestZone and testvalue < calcVal then
            Color = RGB(255, 220, 220)
        elseif testvalue < upTestZone and testvalue > calcVal then
            Color = RGB(220, 255, 220)
        elseif testvalue < downTestZone then
            Color = RGB(255,168,164)
        elseif testvalue > upTestZone then
            Color = RGB(165,227,128)
        end
        SetCell(t_id, i, tableIndex[cell], tostring(calcVal), calcVal)
        cellSetColor(i, tableIndex[cell], Color, RGB(0,0,0))
    end

    if signal then
        local isMessage = SEC_CODES['isMessage'][i]
        local isPlaySound = SEC_CODES['isPlaySound'][i]
        local mes0 = tostring(SEC_CODES['names'][i]).." timescale "..INTERVALS["names"][cell]
        local mes = ""

        if signaltestvalue1 < DS:C(index-1) and signaltestvalue2 > DS:C(index-2) then
            mes = mes0..": ������ Buy"
            myLog(mes)
            --myLog("�������� ��������� -1 "..tostring(signaltestvalue1).." �������� �����-1 "..DS:C(index-1))
            --myLog("�������� ��������� -2 "..tostring(signaltestvalue2).." �������� �����-2 "..DS:C(index-2))
            if isMessage == 1 then message(mes) end
            if isPlaySound == 1 then PaySoundFile(soundFileName) end
        end
        if signaltestvalue1 > DS:C(index-1) and signaltestvalue2 < DS:C(index-2) then
            mes = mes0..": ������ Sell"
            myLog(mes)
            --myLog("�������� ��������� -1 "..tostring(signaltestvalue1).." �������� �����-1 "..DS:C(index-1))
            --myLog("�������� ��������� -2 "..tostring(signaltestvalue2).." �������� �����-2 "..DS:C(index-2))
            if isMessage == 1 then message(mes) end
            if isPlaySound == 1 then PaySoundFile(soundFileName) end
        end

        if testvalue < upTestZone and DS:C(index-1) > upTestZone then
            mes = mes0..": ���� ���������� � ���� "..tostring(upTestZone)
            myLog(mes)
            if isMessage == 1 then message(mes) end
            if isPlaySound == 1 then PaySoundFile(soundFileName) end
        end
        if testvalue > downTestZone and DS:C(index-1) < downTestZone then
            mes = mes0..": ���� ��������� � ���� "..tostring(downTestZone)
            myLog(mes)
            if isMessage == 1 then message(mes) end
            if isPlaySound == 1 then PaySoundFile(soundFileName) end
        end
        if testvalue > upTestZone and DS:C(index-1) < upTestZone then
            mes = mes0..": ���� ������������ �� ���� "..tostring(upTestZone)
            myLog(mes)
            if isMessage == 1 then message(mes) end
            if isPlaySound == 1 then PaySoundFile(soundFileName) end
        end
        if testvalue < downTestZone and DS:C(index-1) > downTestZone then
            mes = mes0..": ���� ���������� �� ���� "..tostring(downTestZone)
            myLog(mes)
            if isMessage == 1 then message(mes) end
            if isPlaySound == 1 then PaySoundFile(soundFileName) end
        end
	end

end

function addDeal(index, ChartId, openLong, openShort, closeLong, closeShort, time)

    label =
    {
        DATE = 0,
        TIME = 0,
        TEXT="***********",
        HINT="",
        FONT_FACE_NAME = "Arial",
        FONT_HEIGHT = 10,
        R = 64,
        G = 192,
        B = 64,
        TRANSPARENT_BACKGROUND = 1,
        YVALUE = 0,
    }

    label.DATE = (time.year*10000+time.month*100+time.day)
    label.TIME = ((time.hour)*10000+(time.min)*100)
    local IMAGE_PATH = getScriptPath()..'\\Pictures\\'

    if openLong ~= nil then
        label.YVALUE = openLong
        label.IMAGE_PATH = IMAGE_PATH..'���������_buy.bmp'
        ALIGNMENT = "BOTTOM"
        label.R = 0
        label.G = 0
        label.B = 0
        label.TEXT = tostring(openLong)
        label.HINT = "open Long "..tostring(openLong)
    elseif openShort ~=nil then
        label.YVALUE = openShort
        label.IMAGE_PATH = IMAGE_PATH..'���������_sell.bmp'
        label.R = 0
        label.G = 0
        label.B = 0
        ALIGNMENT = "TOP"
        label.TEXT = tostring(openShort)
        label.HINT = "open Short "..tostring(openShort)
    elseif closeLong ~=nil then
        label.YVALUE = closeLong
        label.IMAGE_PATH = IMAGE_PATH..'���������_sell.bmp'
        ALIGNMENT = "TOP"
        label.R = 0
        label.G = 0
        label.B = 0
        label.TEXT = tostring(closeLong)
        label.HINT = "close Long "..tostring(closeLong)
    elseif closeShort ~=nil then
        label.YVALUE = closeShort
        label.IMAGE_PATH = IMAGE_PATH..'���������_buy.bmp'
        ALIGNMENT = "BOTTOM"
        label.R = 0
        label.G = 0
        label.B = 0
        label.TEXT = tostring(closeShort)
        label.HINT = "close Short "..tostring(closeShort)
    end

    AddLabel(ChartId, label)

end

function noSignal()
	return {}
end

function getATR(i, dayIntervalIndex)

    local dayDS = nil
    if isDayInterval == false then
        SEC_CODES['dayDS'][i] = CreateDataSource(SEC_CODES['class_codes'][i],SEC_CODES['sec_codes'][i],INTERVAL_D1)
        dayDS = SEC_CODES['dayDS'][i]
    else
        dayDS = SEC_CODES['DS'][i][dayIntervalIndex]
    end
    local scale = getSecurityInfo(SEC_CODES['class_codes'][i],SEC_CODES['sec_codes'][i]).scale
    local dayATR_Period = SEC_CODES['dayATR_Period'][i]
    local lastATR = round(calcDayATR(dayATR_Period, DS), scale)
    SEC_CODES['dayATR'][i] = lastATR
    --myLog("Day ATR ".. SEC_CODE.." "..tostring(lastATR))
    SetCell(t_id, i, tableIndex["D ATR"], tostring(lastATR), lastATR)  --i ������, 1 - �������, v - ��������

    SEC_CODES['D_minus5'][i] = dayDS:C(dayDS:Size()-5)

end

function calcDayATR(dayATR_Period, DS)

    local ATR = {}
    local ind = DS:Size() - 200
    ATR[1] = 0
    --myLog("Day ATR ".. SEC_CODE.." DS:Size() ".. tostring(DS:Size()).." ind "..tostring(ind))

    for index = 2, 200 do

        ATR[index] = ATR[index-1]
        if DS:C(index+ind) ~= nil then

            if index==dayATR_Period then
                local sum=0
                for i = 1, dayATR_Period do
                    sum = sum + dValue(ind+i)
                end
                ATR[index]=sum / dayATR_Period
            elseif index>dayATR_Period then
                ATR[index]=(ATR[index-1] * (dayATR_Period-1) + dValue(index+ind)) / dayATR_Period
            end
            --myLog("Day ATR ".. SEC_CODE.."index ".. tostring(index+ind)..": "..tostring(lastATR))

        end
    end

    return ATR[200] or 0
end

function dValue(i)

    local previous = i-1

    if DS:C(i) == nil then
        previous = FindExistCandle(previous)
    end

    return math.max(math.abs(DS:H(i) - DS:L(i)), math.abs(DS:H(i) - DS:C(previous)), math.abs(DS:C(previous) - DS:L(i)))
end

 -----------------------------
 -- ��������������� ������� --
 -----------------------------
function OnDepoLimit(dlimit)

    if dlimit.limit_kind~=2 then
        return
    end

    for i=1,#SEC_CODES['sec_codes'] do
        if SEC_CODES['sec_codes'][i] == dlimit.sec_code then
            local class_code = SEC_CODES['class_codes'][i]
            local lotsize = tonumber(getParamEx(class_code,dlimit.sec_code,"lotsize").param_value)
            if lotsize == 0 or lotsize == nil then
                lotsize = 1
            end
            SetCell(t_id, i, tableIndex["�������"], tostring(dlimit.currentbal/lotsize), dlimit.currentbal/lotsize)  --i ������, 1 - �������, v - ��������
            local awg_price = GetCorrectPrice(dlimit.awg_position_price, class_code, dlimit.sec_code)
            awg_price = string.gsub(tostring(awg_price),',', '.')
            local last_price = GetCell(t_id, i, tableIndex["������� ����"]).value or 0
            if tonumber(awg_price)==0 then
                SetCell(t_id, i, tableIndex["�������"], '', 0)  --i ������, 1 - �������, v - ��������
                White(i, tableIndex["�������"])
            else
                Str(i, tableIndex["�������"], tonumber(awg_price), last_price)  --i ������, 1 - �������, v - ��������
            end
            if showTradeCommands == true then
                if dlimit.currentbal~=0 then
                    Red(i, tableIndex["������� CLOSE"])
                    SetCell(t_id, i, tableIndex["������� CLOSE"], "CLOSE")  --i ������, 0 - �������, v - ��������
                else
                    White(i, tableIndex["������� CLOSE"])
                    SetCell(t_id, i, tableIndex["������� CLOSE"], "")  --i ������, 0 - �������, v - ��������
                end
            end
            break
        end
    end

end

function OnFuturesClientHolding(fut_limit)

    for i=1,#SEC_CODES['sec_codes'] do
        if SEC_CODES['sec_codes'][i] == fut_limit.sec_code then
            local class_code = SEC_CODES['class_codes'][i]
            local lotsize = tonumber(getParamEx(class_code,fut_limit.sec_code,"lotsize").param_value)
            if lotsize == 0 or lotsize == nil then
                lotsize = 1
            end
            SetCell(t_id, i, tableIndex["�������"], tostring(fut_limit.totalnet/lotsize), fut_limit.totalnet/lotsize)  --i ������, 1 - �������, v - ��������
            local awg_price = GetCorrectPrice(fut_limit.avrposnprice, class_code, fut_limit.sec_code)
            awg_price = string.gsub(tostring(awg_price),',', '.')
            local last_price = GetCell(t_id, i, tableIndex["������� ����"]).value or 0
            if tonumber(awg_price)==0 then
                SetCell(t_id, i, tableIndex["�������"], '', 0)  --i ������, 1 - �������, v - ��������
                White(i, tableIndex["�������"])
            else
                Str(i, tableIndex["�������"], tonumber(awg_price), last_price)  --i ������, 1 - �������, v - ��������
            end
            if showTradeCommands == true then
                if fut_limit.totalnet~=0 then
                    Red(i, tableIndex["������� CLOSE"])
                    SetCell(t_id, i, tableIndex["������� CLOSE"], "CLOSE")  --i ������, 0 - �������, v - ��������
                else
                    White(i, tableIndex["������� CLOSE"])
                    SetCell(t_id, i, tableIndex["������� CLOSE"], "")  --i ������, 0 - �������, v - ��������
                end
            end
            break
        end
    end

end

function GetTotalnet(class_code, sec_code)
    -- ��������, �������
    local opencount = 0
    local awg_position_price = 0

    if class_code == 'SPBFUT' or class_code == 'SPBOPT' then
       for i = 0,getNumberOf('futures_client_holding') - 1 do
          local futures_client_holding = getItem('futures_client_holding',i)
          if futures_client_holding.sec_code == sec_code then
             opencount = futures_client_holding.totalnet
             awg_position_price = GetCorrectPrice(futures_client_holding.avrposnprice, class_code, futures_client_holding.sec_code)
          end
       end
    -- �����
    elseif class_code == 'TQBR' or class_code == 'QJSIM' then
        local lotsize = tonumber(getParamEx(class_code,sec_code,"lotsize").param_value)
        if lotsize == 0 or lotsize == nil then
            lotsize = 1
        end
        --myLog("sec_code "..sec_code.." class_code "..class_code.." lotsize "..tostring(lotsize))
        for i = 0,getNumberOf('depo_limits') - 1 do
          local depo_limit = getItem("depo_limits", i)
          --myLog("trdaccid "..depo_limit.trdaccid.." sec_code "..depo_limit.sec_code.." limit kind "..tostring(depo_limit.limit_kind).." pos: "..tostring(depo_limit.currentbal))
          if depo_limit.sec_code == sec_code
          and depo_limit.trdaccid == ACCOUNT
          and depo_limit.limit_kind == 2 then  -- T+2
            opencount = depo_limit.currentbal/lotsize
            awg_position_price = GetCorrectPrice(depo_limit.awg_position_price, class_code, sec_code)
          end
       end
    end
    awg_position_price = string.gsub(tostring(awg_position_price),',', '.')
    --myLog("awg_position_price "..tostring(awg_position_price))
    --myLog("sec_code "..sec_code.." class_code "..class_code.." pos: "..tostring(opencount))

    -- ���� ������� �� ����������� � ������� �� �������, ���������� 0
    return opencount, awg_position_price
end

function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    local i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

-- ������� ���������� � ��� ������� � �������� � �����
function myLog(str)
    if logFile==nil then return end

    local current_time=os.time()--tonumber(timeformat(getInfoParam("SERVERTIME"))) -- �������� � ���������� ������� ������� � ������� HHMMSS
    if (current_time-g_previous_time)>1 then -- ���� ������� ������ ��������� ����� 1 �������, ��� ����������
        logFile:write("\n") -- ��������� ������ ������ ��� �������� ������
    end
    g_previous_time = current_time

    logFile:write(os.date().."; ".. str .. ";\n")

    if str:find("Script Stoped") ~= nil then
        logFile:write("======================================================================================================================\n\n")
        logFile:write("======================================================================================================================\n")
    end
    logFile:flush() -- ��������� ��������� � �����
end

-- �������� ����� � ����� ����� ���
function removeZero(str)
    while (string.sub(str,-1) == "0" and str ~= "0") do
    str = string.sub(str,1,-2)
    end
    if (string.sub(str,-1) == ".") then
    str = string.sub(str,1,-2)
    end
    return str
end

-- �������� �������� ���� �� �����������
function GetCorrectPrice(price, TRADE_CLASS_CODE, TRADE_SEC_CODE) -- STRING

    local scale = getSecurityInfo(TRADE_CLASS_CODE, TRADE_SEC_CODE).scale
    -- �������� ����������� ��� ���� �����������
    local PriceStep = tonumber(getParamEx(TRADE_CLASS_CODE, TRADE_SEC_CODE, "SEC_PRICE_STEP").param_value)
    -- ���� ����� ������� ������ ���� �����
    if scale > 0 then
        price = tostring(price)
        -- ���� � ����� ������� �������, ��� �����
        local dot_pos = price:find('.')
        local comma_pos = price:find(',')
        -- ���� �������� ����� �����
        if dot_pos == nil and comma_pos == nil then
            -- ��������� � ����� ',' � ����������� ���������� ����� � ���������� ���������
            price = price..','
            for i=1,scale do price = price..'0' end
            return price
        else -- �������� ������������ �����
            -- ���� �����, �������� ������� �� �����
            if comma_pos ~= nil then price:gsub(',', '.') end
            -- ��������� ����� �� ������������ ���������� ������ ����� �������
            price = round(tonumber(price), scale)
            --message(TRADE_SEC_CODE.." price step "..PriceStep.." scale: "..tostring(scale).." price old: "..tostring(price))
            -- ������������ �� ������������ ���� ����
            price = price - price % PriceStep
            --message("price new: "..tostring(price))
            --price = string.gsub(tostring(price),'[\.]+', ',')
            return price
        end
    else -- ����� ������� �� ������ ���� ����
        -- ������������ �� ������������ ���� ����
        price = price - price % PriceStep
        return tostring(math.floor(price))
    end
end

function PaySoundFile(file_name)
    w32.mciSendString("CLOSE QUIK_MP3")
    w32.mciSendString("OPEN \"" .. file_name .. "\" TYPE MpegVideo ALIAS QUIK_MP3")
    w32.mciSendString("PLAY QUIK_MP3")
end

function round(num, idp)
    if num then
    local mult = 10^(idp or 0)
    if num >= 0 then return math.floor(num * mult + 0.5) / mult
    else return math.ceil(num * mult - 0.5) / mult end
    else return num end
end

function FindExistCandle(I)

    local out = I

    while DS:C(out) == nil and out > 0 do
        out = out -1
    end

    return out

end

function toYYYYMMDDHHMMSS(datetime)
    if type(datetime) ~= "table" then
       --message("� ������� toYYYYMMDDHHMMSS ������� ����� ��������: datetime="..tostring(datetime))
       return ""
    else
       local Res = tostring(datetime.year)
       if #Res == 1 then Res = "000"..Res end
       local month = tostring(datetime.month)
       if #month == 1 then Res = Res.."/0"..month; else Res = Res..'/'..month; end
       local day = tostring(datetime.day)
       if #day == 1 then Res = Res.."/0"..day; else Res = Res..'/'..day; end
       local hour = tostring(datetime.hour)
       if #hour == 1 then Res = Res.." 0"..hour; else Res = Res..' '..hour; end
       local minute = tostring(datetime.min)
       if #minute == 1 then Res = Res..":0"..minute; else Res = Res..':'..minute; end
       local sec = tostring(datetime.sec);
       if #sec == 1 then Res = Res..":0"..sec; else Res = Res..':'..sec; end;
       return Res
    end
end --toYYYYMMDDHHMMSS

function isnil(a,b)
    if a == nil then
       return b
    else
       return a
    end;
end