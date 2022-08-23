local config
local penalty = require("kindi.signpost fast travel.penalties")
local destination = require("kindi.signpost fast travel.destination")

local function tryDetermineCell(name)
    if destination[name] then
        return name
    end
    for str in name:gmatch("[^,%s]+") do
        if destination[str] then
            return str
        end
    end
end

local function postFastTravel(e, CELL, travelType)

    -- //playbink here i guess?
    -- //tes3.runLegacyScript{command = string.format('playbink "%s" 1', "?")}

    -- //if traveller is in combat and the option is enabled, travelling is disabled
    if config.combatDeny and e.activator.mobile.inCombat then
        tes3.messageBox("You can't travel when enemies are nearby.")
        tes3.fadeIn({duration = 2})
        return
    end

    -- //travel immediately to the preset position of this town
    tes3.positionCell {
        reference = e.activator,
        cell = CELL,
        position = destination[CELL].position,
        orientation = destination[CELL].orientation,
        suppressFader = false,
        teleportCompanions = config.bringFriends
    }


    local TM -- travel
    local DM -- divine
    local AM -- almsivi

    -- //find these markers reference in active cells (usually covers a whole town)
    for _, cell in pairs(tes3.getActiveCells()) do
        if cell.id:lower() == e.activator.cell.id:lower() then
            for ref in cell:iterateReferences() do
                if ref.object.id == "TempleMarker" then
                    AM = ref
                end
                if ref.object.id == "DivineMarker" then
                    DM = ref
                end
                if ref.object.id == "TravelMarker" then
                    TM = ref
                end
            end
        end
    end

    --//get the markers position and orientation
    local function getTravel(travelType)
        if travelType == "TravelMarker" and TM then
            return TM.position, TM.orientation
        elseif travelType == "DivineMarker" and DM then
            return DM.position, DM.orientation
        elseif travelType == "TempleMarker" and AM then
            return AM.position, AM.orientation
        elseif travelType == "Preset" then
            return false
        else
            return false
        end
    end

    -- //priority check for the travel point 1,2,3,4
    -- //if any of those points are found first, reposition to that point
    for i = 1, 4 do
        local arrivalPos -- arrival position
        local arrivalAng -- arrival angle 
        arrivalPos, arrivalAng = getTravel(config["travelTo" .. i])
        if arrivalPos and arrivalAng and tes3.positionCell {
            reference = e.activator,
            cell = CELL,
            position = arrivalPos,
            orientation = arrivalAng,
            teleportCompanions = config.bringFriends
        } then
            if config.debug then
                tes3.messageBox("Using ".. config["travelTo" .. i] .." point")
            end
            break
        end
        if arrivalPos == false then
            break
        end
    end

    -- //move on to the penalty section (health, fatigue, time advance, gold, disease, etc...)
    timer.delayOneFrame(function()penalty.penalties(e.activator, e.target.position:copy(), e.target, travelType, CELL)
        tes3.fadeIn({duration = 6})
    end)
end

local function postActivated(e)

    --// if mod is off, travel is disabled
    if not config.modActive then
        return
    end

    --//if target activation is not a activator type, travel is disabled
    --//signposts are and should be activators
    if e.target.object.objectType ~= tes3.objectType.activator then
        return
    end

    --//determine if this cell is in the list, if not travel is disabled
    local CELL = tryDetermineCell(e.target.object.name)


    --//if there is no valid cell matching the signpost, travel is disabled
    --//note: some signposts may show invalid cell names, for now just ignore them
    if not CELL then
        if config.debug then
            tes3.messageBox("Unable to find any cell that matches %s", e.target.object.name)
        end
        return
    end

    -- //reset? deactivate any transition fader to start a new one from this mod
    tes3.worldController.transitionFader:deactivate()
    tes3.fadeOut({duration = 0.3})

    --//check if confirmation is needed and if 'extra realism' mode is enabled, then proceed to the next stage
    if config.showConfirm then
        if config.extraRealism then
            tes3.messageBox {
                message = string.format("Travel to %s?", e.target.object.name),
                buttons = {"Recklessly", "Cautiously", "No"},
                callback = function(b)
                    if b.button == 0 then
                        postFastTravel(e, CELL, "Reckless")
                    elseif b.button == 1 then
                        postFastTravel(e, CELL, "Cautious")
                    else
                        tes3.fadeIn({duration = 2})
                    end
                end
            }
        else
            tes3.messageBox {
                message = string.format("Travel to %s?", e.target.object.name),
                buttons = {"Yes", "No"},
                callback = function(b)
                    if b.button == 0 then
                        postFastTravel(e, CELL)
                    else
                        tes3.fadeIn({duration = 2})
                    end
                end
            }
        end
    else
        postFastTravel(e, CELL)
    end

end

event.register("activate", postActivated)

event.register("modConfigReady", function()
    config = require("kindi.signpost fast travel.config")
    require("kindi.signpost fast travel.mcm")
end)
