--peripherals
local sideGateOutput = "right"
local sideReactor = "back"

local preferredFieldStrength = 0.01
local preferredFieldStrengthLaunching = 0.1
local preferredFieldStrengthStopping = 0.1

local preferredInflowCharging = -1


--Do not change code below

local version = "1.0.1"

--shutdown parameters
local shutdownTemperature = 8005.0
local shutdownFieldStrength = 0.007
local shutdownFuelConversion = 0.9

--other
local preferredTemperature = 8000.0
local fastLaunchOffsetTemperature = 7500.0
local fastLaunchOffsetTemperature2 = 7800.0
local fastLaunchOffsetTemperature3 = 7984.0

local preferredInflowStarting = 200000
local preferredOutflowLaunching = 1000000

--program variables

local doUpdate = true
local initiateStatusChange = "no"

--peripherals
local reactor
local gateInput
local gateOutput

--reactor info

--max values
local maxFieldStrength
local maxEnergySaturation
local maxFuelConversion

--current values
local currentReactorStatus
local currentTemperature
local currentFieldStrengthRaw
local currentFieldStrength
local currentFieldDrainRate
local currentEnergySaturationRaw
local currentEnergySaturation
local currentFuelConversionRaw
local currentFuelConversion
local currentFuelConversionRate
local currentGenerationRate

local currentTicksSinceStatusChange
local currentInflow
local currentOutflow
local currentNettoGeneration

--last values
local lastReactorStatus
local lastTemperature
local lastFieldStrengthRaw
local lastFieldStrength
local lastFieldDrainRate
local lastEnergySaturationRaw
local lastEnergySaturation
local lastFuelConversionRaw
local lastFuelConversion
local lastFuelConversionRate
local lastGenerationRate

--other values
local infoHighestTemperature = 0.0
local infoLowestFieldStrength = 1.0
local infoLowestSaturation = 1.0

--read reactor info
function updateReactorInfo()
	local reactorInfo = reactor.getReactorInfo()
	
	if reactorInfo == nil then
      error("Reactor has an invalid setup!")
    end
	
	lastReactorStatus 		= currentReactorStatus
	lastTemperature 		= currentTemperature
	lastFieldStrengthRaw 	= currentFieldStrengthRaw
	lastFieldStrength 		= currentFieldStrength
	lastFieldDrainRate 		= currentFieldDrainRate
	lastEnergySaturationRaw = currentEnergySaturationRaw
	lastEnergySaturation 	= currentEnergySaturation
	lastFuelConversionRaw 	= currentFuelConversionRaw
	lastFuelConversion 		= currentFuelConversion
	lastFuelConversionRate 	= currentFuelConversionRate
	lastGenerationRate 		= currentGenerationRate
	
	
	maxFieldStrength 			= reactorInfo.maxFieldStrength
	maxEnergySaturation 		= reactorInfo.maxEnergySaturation
	maxFuelConversion 			= reactorInfo.maxFuelConversion
	
	currentTemperature 			= reactorInfo.temperature
	currentFieldStrengthRaw 	= reactorInfo.fieldStrength
	currentEnergySaturationRaw 	= reactorInfo.energySaturation
	currentFuelConversionRaw 	= reactorInfo.fuelConversion
	currentGenerationRate 		= reactorInfo.generationRate
	currentFieldDrainRate 		= reactorInfo.fieldDrainRate
	currentFuelConversionRate 	= reactorInfo.fuelConversionRate
	currentReactorStatus 		= reactorInfo.status
	
	currentFieldStrength 		= 1.0 * currentFieldStrengthRaw / maxFieldStrength
	currentEnergySaturation 	= 1.0 * currentEnergySaturationRaw / maxEnergySaturation
	currentFuelConversion 		= 1.0 * currentFuelConversionRaw / maxFuelConversion
	
	
	if currentReactorStatus ~= lastReactorStatus then
		ticksSinceStatusChange = 0
	else
		ticksSinceStatusChange = ticksSinceStatusChange + 1
	end
	
	currentInflow = gateInput.getFlow()
	currentOutflow = gateOutput.getFlow()
	currentNettoGeneration = currentGenerationRate - currentInflow
	
	if currentTemperature > infoHighestTemperature then
		infoHighestTemperature = currentTemperature
	end
	if (status == "online" or status == "stopping") and (currentFieldStrength < infoLowestFieldStrength) then
		infoLowestFieldStrength = currentFieldStrength
	end
	if (status == "online" or status == "stopping") and (currentEnergySaturation < infoLowestSaturation) then
		infoLowestSaturation = currentEnergySaturation
	end
end

function setup()
	setupPeripherals()
	
	currentTicksSinceStatusChange = 0
	
	updateReactorInfo()
	updateReactorInfo()

	if preferredInflowCharging == -1 then
		preferredInflowCharging = 10000000
	end
end

function setupPeripherals()
	reactor = peripheral.wrap(sideReactor)
	monitor = periphSearch("monitor")
	gateInput = periphSearch("flux_gate")
	gateOutput = peripheral.wrap(sideGateOutput)
	
	if reactor == null then
		error("No valid reactor was found!")
	end
	if gateInput == null then
		error("No valid input fluxgate was found!")
	end	 
	if gateOutput == null then
		error("No valid output fluxgate was found!")
	end
	
	gateInput.setOverrideEnabled(true)
	gateOutput.setOverrideEnabled(true)
end
function periphSearch(type)
   local names = peripheral.getNames()
   local i, name
   for i, name in pairs(names) do
      if peripheral.getType(name) == type then
         return peripheral.wrap(name)
      end
   end
   return null
end

function update()
	doUpdate = true
	
	local newInflow
	local newOutflow
	local isStable
	
	while doUpdate do
		updateReactorInfo()		
		
		newInflow = currentInflow
		newOutflow = 0
		isStable = false
		
		if currentReactorStatus == "offline" then
			newInflow = 0
		elseif currentReactorStatus == "charging" then
			newInflow = preferredInflowCharging
		elseif currentReactorStatus == "charged" then
			newInflow = preferredInflowStarting
			newOutflow = preferredOutflowLaunching
			reactor.activateReactor()
		elseif currentReactorStatus == "online" then
			if currentTemperature < (fastLaunchOffsetTemperature + 2000) / 2 then
				newOutflow = preferredOutflowLaunching*1.2
			elseif currentTemperature < fastLaunchOffsetTemperature then
				newOutflow = preferredOutflowLaunching*0.99
			elseif currentTemperature < fastLaunchOffsetTemperature2 then
				newOutflow = currentGenerationRate + (preferredOutflowLaunching - currentGenerationRate)/10
			elseif currentTemperature < fastLaunchOffsetTemperature3 then
				newOutflow = currentGenerationRate + (preferredOutflowLaunching - currentGenerationRate)/20
			elseif currentTemperature < preferredTemperature then
				newOutflow = currentGenerationRate + 100
			elseif currentTemperature < preferredTemperature + 0.1 then
				newOutflow = currentGenerationRate - 1
			elseif currentTemperature >= preferredTemperature + 0.1 then
				newOutflow = currentGenerationRate - 100
			end
			
			newInflow = calcInflow(preferredFieldStrengthLaunching)*1.1
			
			if (currentTemperature > preferredTemperature - 15) and (currentTemperature < preferredTemperature + 2) then
				isStable = true
				
				if currentFieldStrength < preferredFieldStrength*0.99 then
					newInflow = calcInflow(preferredFieldStrength)*1.1
				elseif currentFieldStrength < preferredFieldStrength*0.999 then
					newInflow = calcInflow(preferredFieldStrength)*1.001
				elseif currentFieldStrength < preferredFieldStrength*1.5 then
					newInflow = calcInflow(preferredFieldStrength)
				else
					newInflow = 0
				end
			elseif currentFieldStrength > preferredFieldStrengthLaunching*2 then
				newInflow = 0
			--else
			--	newInflow = calcInflow(preferredFieldStrengthLaunching)*1.1
			end			
			
			if isEmergency() then
				reactor.stopReactor()
				newInflow = calcInflowCorrected(preferredFieldStrengthStopping*2.0)
				newOutflow = 0
			elseif currentFuelConversion >= shutdownFuelConversion then
				reactor.stopReactor()
				newOutflow = 0
			end
		elseif currentReactorStatus == "stopping" then
			if isEmergency() then
				newInflow = calcInflowCorrected(preferredFieldStrengthStopping*2.0)
			elseif currentFieldStrength < preferredFieldStrengthStopping*0.98 then
				newInflow = calcInflow(preferredFieldStrengthStopping)*2
			elseif currentFieldStrength < preferredFieldStrengthStopping*2.0 then
				newInflow = calcInflow(preferredFieldStrengthStopping)
			else
				newInflow = 0
			end
		end
				
		
		--newInflow = math.floor(newInflow)
		--newOutflow = math.floor(newOutflow)
		if newInflow < 0 then
			newInflow = 0
		end
		if newOutflow < 0 then
			newOutflow = 0
		end		
		gateInput.setFlowOverride(newInflow)
		gateOutput.setFlowOverride(newOutflow)		
				
		
		term.clear()
		print("version: " .. version)
		print("")
		print("highest Temp: " .. infoHighestTemperature .. "K")
		print("lowest field: " .. (math.floor(infoLowestFieldStrength*100000)/1000) .. "%")
		print("lowest sat:   " .. (math.floor(infoLowestSaturation*100000)/1000) .. "%")
		print("------------------------------------------")
		print("temperature: " .. currentTemperature .. "K")
		print("field:       " .. (math.floor(currentFieldStrength*10000)/100) .. "%")
		print("saturation:  " .. (math.floor(currentEnergySaturation*10000)/100) .. "%")
		print("inflow:      " .. currentInflow .. "RF/t")
		if currentNettoGeneration > 0 then
			print("netto:      +" .. currentNettoGeneration .. "RF/t")
		else
			print("netto:       " .. currentNettoGeneration .. "RF/t")
		end
		print("fuel left:   " .. (math.floor((1.0 - currentFuelConversion)*10000)/100) .. "%")
		print("efficiency:  " .. currentFuelConversionRate .. "nb/t")
		if isStable then
			print("status:      " .. currentReactorStatus .. " (stable)")
		else
			print("status:      " .. currentReactorStatus)
		end
		
		sleep(0.1)
	end
end

function calcInflowManual(targetStrength, fieldDrainRate)
	return fieldDrainRate / (1.0 - targetStrength)
end
function calcInflow(targetStrength)
	return calcInflowManual(targetStrength, currentFieldDrainRate)
end
function calcInflowCorrected(targetStrength)
	return calcInflowManual(targetStrength, currentFieldDrainRate)*20 - calcInflowManual(lastFieldStrength, lastFieldDrainRate)*19
end

function isEmergency()
	return currentTemperature >= shutdownTemperature or currentFieldStrength <= shutdownFieldStrength
end

--------------------------

function main()
	setup()
	update()
end

main()
