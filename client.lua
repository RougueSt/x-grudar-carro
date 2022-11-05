--[[
+----------------------------------------------------------------------------
|   GLUE SCRIPT
|   ========================================
|	This glue script aims to be better than the older, original glue resources from around 2009.
|	It's more resistant against desync bugs and features both vehicle-to-vehicle and player-to-vehicle glue'ing.
|	You can customize quite a few settings, and for example prevent players from shooting while ontop of a vehicle.
|	It can be turned into only player-to-vehicle (on foot) or vehicle-on-vehicle glue'ing only, by customizing below settings.
+-----------------------------------------------------------------------------
|	Always make sure to get the latest version update of this resource!
|   at https://community.mtasa.com/index.php?p=resources&s=details&id=15189
+-----------------------------------------------------------------------------
]] --

-- SCRIPT SETTINGS --
local letPlayersAttachVehicles = true --Global attachment variable. NOTE: DISABLING THIS WILL PREVENT THE ATTACHMENT AND WHITELIST WON'T AFFECT THIS.
local attachWithPositionOverVehicle = false --If true, vehicles will attach over the top of target vehicle. If false, vehicles will attach but will maintain original position (seamless, precise glue'ing).
local globalGluePlayers = true --Allow players to glue to cars while on foot
local globalGlueVehicles = false --Allow vehicles to attach (glue) to other vehicles
local globalGlueHelis = true --Allow helicopters to attach vehicles to them (pick them up into the air)
local allowedGeneralVehicles = {500, 411, 443, 520} --Whitelist if globalGlueVehicles is false
local allowedHelis = {487, 411, 520} --Whitelist if globalGlueHelis is false
local preventPlayerFromFiring = true --Prevent players from shooting their guns while glue'd on vehicles?

function globalVehicleGlueCheck(vehicle)
	if globalGlueVehicles then
		return true
	else
		for i, vehicles in ipairs(allowedGeneralVehicles) do
			if getElementModel(vehicle) == vehicles then
				return true
			end
		end
		return false
	end
end

function getAttachedVehicle(vehicle)
	for i, attached in ipairs(getAttachedElements(vehicle)) do
		if getElementType(attached) == "vehicle" then
			return attached
		end
	end
	return false
end

function globalHeliGlueCheck(vehicle)
	if globalGlueHelis then
		return true
	else
		for i, vehicles in ipairs(allowedHelis) do
			if getElementModel(vehicle) == vehicles then
				return true
			end
		end
		return false
	end
end

function getOffsetFromXYZ(mat, vec)
	mat[1][4] = 0
	mat[2][4] = 0
	mat[3][4] = 0
	mat[4][4] = 1
	mat = matrix.invert(mat)
	local offX = vec[1] * mat[1][1] + vec[2] * mat[2][1] + vec[3] * mat[3][1] + mat[4][1]
	local offY = vec[1] * mat[1][2] + vec[2] * mat[2][2] + vec[3] * mat[3][2] + mat[4][2]
	local offZ = vec[1] * mat[1][3] + vec[2] * mat[2][3] + vec[3] * mat[3][3] + mat[4][3]
	return {offX, offY, offZ}
end

function switchPlayerFromFiringIfEnabled(bool)
	if preventPlayerFromFiring then
		toggleControl("fire", bool)
		toggleControl("action", bool)
	end
end

function setOffsetsByVar(getOffsetFromElement, getOffsetToElement)
	local rotpX, rotpY, rotpZ = getElementRotation(getOffsetFromElement)
	local rotvX, rotvY, rotvZ = getElementRotation(getOffsetToElement)
	local rotX = rotpX - rotvX
	local rotY = rotpY - rotvY
	local rotZ = rotpZ - rotvZ
	if attachWithPositionOverVehicle then
		local nearBOMDist = getElementDistanceFromCentreOfMassToBaseOfModel(getOffsetToElement)
		local occDist = getElementDistanceFromCentreOfMassToBaseOfModel(getOffsetFromElement)
		return 0, 0, 1.5, rotX, rotY, rotZ
	else
		local oX, oY, oZ = getElementPosition(getOffsetFromElement)
		local x, y, z = unpack(getOffsetFromXYZ(getElementMatrix(getOffsetToElement), {oX, oY, oZ}))
		return x, y, z, rotX, rotY, rotZ
	end
end

function getNearestVehicleFromVehicle(vehicle)
	for i, vehicles in ipairs(getElementsByType("vehicle")) do
		local x, y, z = getElementPosition(vehicle)
		local nx, ny, nz = getElementPosition(vehicles)
		local distanceFromVehicle = getDistanceBetweenPoints3D(x, y, z, nx, ny, nz)
		if distanceFromVehicle < 5 and vehicles ~= vehicle then
			return vehicles
		end
	end
	return false
end

function ungluePlayer()
	local occVehicle = getPedOccupiedVehicle(localPlayer)
	if occVehicle then
		if not getAttachedVehicle(occVehicle) and not isElementAttached(occVehicle) then
			gluePlayer()
			return
		end
		local occVehicleOccupant = getVehicleOccupant(occVehicle, 0)
		if (occVehicleOccupant and occVehicleOccupant == localPlayer) then
			if (isElementAttached(occVehicle)) then
				triggerServerEvent("detachElements", occVehicle)
				bindKey("x", "down", gluePlayer)
				unbindKey("x", "down", ungluePlayer)
			else
				if getVehicleType(occVehicle) == "Helicopter" then
					local attachedVeh = getAttachedVehicle(occVehicle)
					if attachedVeh then
						triggerServerEvent("detachElements", attachedVeh)
						bindKey("x", "down", gluePlayer)
						unbindKey("x", "down", ungluePlayer)
					end
				else
					gluePlayer()
				end
			end
		end
		occVehicleOccupant = nil
		occVehicle = nil
	else
		if isElementAttached(localPlayer) then
			triggerServerEvent("detachElements", localPlayer)
			switchPlayerFromFiringIfEnabled(true)
			bindKey("x", "down", gluePlayer)
			unbindKey("x", "down", ungluePlayer)
		else
			gluePlayer()
		end
	end
end

function gluePlayer()
	local occVehicle = getPedOccupiedVehicle(localPlayer)
	if occVehicle then
		local occVehicleOccupant = getVehicleOccupant(occVehicle, 0)
		if (occVehicleOccupant) then
			if not letPlayersAttachVehicles or occVehicleOccupant ~= localPlayer then
				return
			end

			if getAttachedVehicle(occVehicle) and getElementType(occVehicle) == "Helicopter" then
				ungluePlayer()
				return
			end

			if isElementAttached(occVehicle) and globalVehicleGlueCheck then
				triggerServerEvent("detachElements", occVehicle)
				occVehicle = nil
				return
			end

			local occX, occY, occZ = getElementPosition(occVehicle)
			local occRotX, occRotY, occRotZ = getElementRotation(occVehicle)
			local nearVeh = getNearestVehicleFromVehicle(occVehicle)
			if (nearVeh) then
				local nx, ny, nz = getElementPosition(nearVeh)
				if getVehicleType(occVehicle) == "Helicopter" and globalHeliGlueCheck(occVehicle) then
					if not getAttachedVehicle(occVehicle) then
						local x, y, z = 0, 0, -1.5
						triggerServerEvent("attachElements", nearVeh, occVehicle, x, y, z, 0, 0, 0)
					else
						triggerServerEvent("detachElements", getAttachedVehicle(occVehicle))
					end
				elseif globalVehicleGlueCheck(occVehicle) then
					local x, y, z, rx, ry, rz = setOffsetsByVar(occVehicle, nearVeh)
					triggerServerEvent("attachElements", occVehicle, nearVeh, x, y, z, rx, ry, rz)
				end
			end
		end
		occVehicle = nil
	else
		local contactElement = getPedContactElement(localPlayer)
		if (contactElement and getElementType(contactElement) == "vehicle") and globalGluePlayers then
			local vx, vy, vz = getElementPosition(contactElement)
			local xx, yy, zz = getElementPosition(localPlayer)
			local x, y, z = unpack(getOffsetFromXYZ(getElementMatrix(contactElement), {xx, yy, zz}))
			local r, r, rotz = getElementRotation(localPlayer)
			local slot = getPedWeaponSlot(localPlayer)
			triggerServerEvent("attachElements", localPlayer, contactElement, x, y, z, 0, 0, 0, slot)
			switchPlayerFromFiringIfEnabled(false)
		end
		contactElement = nil
	end
end

local function bindGlue()
	unbindKey("x", "down", gluePlayer)
	bindKey("x", "down", ungluePlayer)
end
bindKey("x", "down", gluePlayer)
addEvent("bindGlue", true)
addEventHandler("bindGlue", localPlayer, bindGlue)

addEventHandler("onClientElementDestroy", root,
	function()
		if getElementAttachedTo(localPlayer) and source == getElementAttachedTo(localPlayer) then
			switchPlayerFromFiringIfEnabled(true)
		end
	end
)