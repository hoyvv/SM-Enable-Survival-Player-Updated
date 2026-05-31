_G.GlobalOptionGate = nil

---@class OptionGate : ShapeClass 
TeamsGate = class()

local GUI_LAYOUT = "$CONTENT_DATA/Gui/Layouts/TeamsGateLayout.layout"

local function hexToSmColor(hex)
    hex = hex:gsub("#", "")
    local r_num = tonumber(hex:sub(1, 2), 16) or 0
    local g_num = tonumber(hex:sub(3, 4), 16) or 0
    local b_num = tonumber(hex:sub(5, 6), 16) or 0
    return sm.color.new(r_num / 255, g_num / 255, b_num / 255)
end

function TeamsGate:server_onCreate()
    if _G.GlobalOptionGate and sm.exists(_G.GlobalOptionGate) then
        _G.GlobalOptionGate:destroyShape()
    end

    _G.GlobalOptionGate = self.shape
end

function TeamsGate:server_onDestroy()
    if _G.GlobalOptionGate == self.shape then
        _G.GlobalOptionGate = nil
    end
end

function TeamsGate:sv_chatMessageSingle(msg, caller)
    sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {caller, msg})
end

function TeamsGate:sv_createTeam(args, caller)
    if args.name == "" then
        sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {caller, "#FF0000TEAM NAME CANNOT BE EMPTY!"})
        return
    end
    sm.event.sendToTool(sm.PLAYERHOOK, "sv_handleCreateTeamCommand", { 
            [1] = "/createteam",
            [2] = args.name,
            [3] = args.isCustomSpawn,
            [4] = args.colour,
            player = caller
        })
end

function TeamsGate:sv_deleteTeam(selectedTeam, caller)
    if selectedTeam == "" then return end
    sm.event.sendToTool(sm.PLAYERHOOK, "sv_handleDeleteTeamCommand", {
        [1] = "/deleteteam",
        [2] = selectedTeam,
        player = caller
    })
end

function TeamsGate:sv_renameTeam(args, caller)
    if args.selectedTeam == "" or args.newTeamName == "" then return end
    sm.event.sendToTool(sm.PLAYERHOOK, "sv_handleRenameTeamCommand", {
        [1] = "/renameteam",
        [2] = args.selectedTeam,
        [3] = args.newTeamName,
        player = caller
    })
    self.network:sendToClient(caller, "cl_disableRenameTeamEdit")
end

function TeamsGate:cl_alert(msg)
    sm.gui.displayAlertText(msg, 2.5)
end

function TeamsGate:client_onCreate()
    self.gui = nil
end

function TeamsGate:client_onDestroy()
    self:cl_onGuiCloseCallback()
end

function TeamsGate:client_canInteract()
    local use_key = sm.gui.getKeyBinding("Use", true)
    sm.gui.setInteractionText("Press", use_key, "to open gui")
    return true
end

function TeamsGate:client_canErase()
    if not sm.isHost then
        self:cl_alert("Only the host can remove this block!")
        return false
    end

    return true
end

function TeamsGate:client_onInteract(character, lookAt)
    if not lookAt then return end

    if not sm.isHost then
        self:cl_alert("Host only.")
        return
    end

    local gui = sm.gui.createGuiFromLayout(GUI_LAYOUT, false, { backgroundAlpha = 0.5 })

    gui:setButtonCallback("customSpawnOn", "cl_onCustomSpawnChanged")
    gui:setButtonCallback("customSpawnOff", "cl_onCustomSpawnChanged")
    gui:setTextChangedCallback("teamNameEditBox", "cl_onTeamNameChanged")
    gui:setTextAcceptedCallback("teamColorEditBox", "cl_onTeamColorAccepted")
    gui:setTextAcceptedCallback("teamRenameEditBox", "cl_onTeamRenameAccepted")
    gui:setButtonCallback("createTeamButton", "cl_onCreateTeamPressed")
    gui:setButtonCallback("nextPage", "cl_onPageChange")
    gui:setButtonCallback("prevPage", "cl_onPageChange")
    gui:setButtonCallback("deleteTeamButton", "onSelectedMenuButtonClick")
    gui:setButtonCallback("renameTeamButton", "onSelectedMenuButtonClick")
    gui:setOnCloseCallback("cl_onGuiCloseCallback")

    for i = 1, 5 do
        gui:setButtonCallback("tItem" .. i, "cl_onTeamClick")
    end

    gui:setText("selectedTeamText", "")
    gui:setVisible("teamRenameEditBox", false)
    gui:setButtonState("customSpawnOn", true)
    gui:setButtonState("customSpawnOff", false)

    self.teamBuilderData = {
        name = "",
        isCustomSpawn = true,
        colour = "#888888"
    }
    self.pageData = {}
    self.maxPage = 1
    self.currentPage = self.maxPage
    self.selectedTeam = ""
    
    self.gui = gui
    self.gui:open()

    self:cl_updateTeamList()
end

function TeamsGate:client_onFixedUpdate()
    if self.gui and sm.exists(self.gui) and self.gui:isActive() then
        self:cl_updateTeamList()
    end
end

function TeamsGate:cl_onCustomSpawnChanged(widgetName)
    if widgetName == "customSpawnOn" then
        self.teamBuilderData.isCustomSpawn = true
        self.gui:setButtonState("customSpawnOn", true)
        self.gui:setButtonState("customSpawnOff", false)
    elseif widgetName == "customSpawnOff" then
        self.teamBuilderData.isCustomSpawn = false
        self.gui:setButtonState("customSpawnOn", false)
        self.gui:setButtonState("customSpawnOff", true)
    end
end

function TeamsGate:cl_onTeamNameChanged(widgetName, text)
    self.gui:setText(widgetName, self.teamBuilderData.colour .. text)
    self.teamBuilderData.name = text
end

function TeamsGate:cl_onTeamColorAccepted(widgetName, text)
    local clean = text:gsub("[^%x]", ""):sub(1, 6)
    local result = "#" .. (clean .. "000000"):sub(1, 6)
    if self.teamBuilderData.colour ~= result then
        self.teamBuilderData.colour = result
        self.gui:setText("teamNameEditBox", result .. self.teamBuilderData.name)
        self.gui:setColor("teamColorImageBox", hexToSmColor(result))
    end
    if text ~= result then
        self.gui:setText("teamColorEditBox", result)
    end
end

function TeamsGate:cl_onCreateTeamPressed(widgetName)
    if self.teamBuilderData.name ~= "" then
        self.gui:setText("teamNameEditBox", "")
    end

    self.network:sendToServer("sv_createTeam", self.teamBuilderData)
end

function TeamsGate:cl_onPageChange(widgetName)
    local oldPage = self.currentPage

    if widgetName == "nextPage" then
        self.currentPage = math.min(self.currentPage + 1, self.maxPage)
    elseif widgetName == "prevPage" then
        self.currentPage = math.max(self.currentPage - 1, 1)
    end

    if oldPage ~= self.currentPage then
        self:updateCurrentPage()
        self:cl_updateTeamList()
    end
end

function TeamsGate:updateCurrentPage()
    self.gui:setText("currentPage", tostring(self.currentPage) .. "/" .. tostring(self.maxPage))
end

function TeamsGate:cl_updateTeamList()
    local teamKeys = {}
    for name, _ in pairs(sm.SURVIVAL_EXTENSION.teams) do
        table.insert(teamKeys, name)
    end
    table.sort(teamKeys)

    self.maxPage = math.max(1, math.ceil(#teamKeys / 5))

    if self.currentPage > self.maxPage then
        self.currentPage = self.maxPage
    end

    self:updateCurrentPage()

    for i = 1, 5 do
        local actualI = self.currentPage * 5 - 5 + i
        local teamName = teamKeys[actualI]
        self.pageData[i] = teamName
        if teamName then     
            self.gui:setText("tItem" .. i, teamName)
            self.gui:setVisible("tItem" .. i, true)
        else
            self.gui:setVisible("tItem" .. i, false)
        end
    end
end

function TeamsGate:cl_onTeamClick(widgetName)
    local index = tonumber(string.sub(widgetName, -1))
    local teamName = self.pageData[index]
    if teamName then
        self.selectedTeam = teamName
        self.gui:setVisible("teamRenameEditBox", false)
        self.gui:setVisible("selectedTeamText", true)
        self.gui:setText("selectedTeamText", teamName)
    end
end

function TeamsGate:onSelectedMenuButtonClick(widgetName)
    if self.selectedTeam == "" then
        self.network:sendToServer("sv_chatMessageSingle", "#FF0000PLEASE SELECT A TEAM FIRST!")
        return 
    end

    if widgetName == "deleteTeamButton" then
        self.network:sendToServer("sv_deleteTeam", self.selectedTeam)
        self.selectedTeam = ""
        self.gui:setText("selectedTeamText", "")
    elseif widgetName == "renameTeamButton" then
        self.gui:setText("teamRenameEditBox", "")
        self.gui:setVisible("teamRenameEditBox", true)
        self.gui:setVisible("selectedTeamText", false)
        self.gui:setFocus("teamRenameEditBox")
    end
end

function TeamsGate:cl_onTeamRenameAccepted(widgetName, text)
    self.network:sendToServer("sv_renameTeam", {
        selectedTeam = self.selectedTeam,
        newTeamName = text
    })
    self.gui:setFocus("")
end

function TeamsGate:cl_disableRenameTeamEdit()
    if self.gui and sm.exists(self.gui) then
        self.gui:setText("teamRenameEditBox", "")
        self.gui:setVisible("teamRenameEditBox", false)
    end
end

function TeamsGate:cl_onGuiCloseCallback()
	local gui = self.gui
	if gui and sm.exists(gui) then
		if gui:isActive() then
			gui:close()
		end

		gui:destroy()
	end

	self.gui = nil
end

