---@class JoinGate : ShapeClass
JoinGate = class()

local GUI_LAYOUT = "$CONTENT_DATA/Gui/Layouts/JoinGateLayout.layout"

function JoinGate:server_onCreate()
	local savedData = self.storage:load()
	if savedData then
		self.network:setClientData(savedData)
	end
end

function JoinGate:sv_setTeam(teamName, caller)
	if teamName == "" or teamName == nil then
		return
	end

	if sm.SURVIVAL_EXTENSION.teams[teamName] == nil then
		return
	end

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_handleSetTeamCommand", {
		[1] = "/setteam",
		[2] = teamName,
		player = caller,
	})
end

function JoinGate:sv_saveSelectedTeam(teamData)
	self.storage:save(teamData)
	self.network:setClientData(teamData)
end

function JoinGate:client_onCreate()
	self.gui = nil
	self.sortedTeams = {}

	self.selectedTeamData = {
		name = "",
		colour = "#888888",
	}

	self.maxPage = 1
	self.currentPage = 1
	self.selectedTeamName = ""
end

function JoinGate:client_onClientDataUpdate(data)
	if data then
		self.selectedTeamData = data
	end
end

function JoinGate:client_onDestroy()
	self:cl_destroyGui()
end

function JoinGate:client_canInteract()
	sm.gui.setInteractionText("Press", sm.gui.getKeyBinding("Use", true), "to open gui")
	return true
end

function JoinGate:client_canTinker()
	sm.gui.setInteractionText("Press", sm.gui.getKeyBinding("Use", true), "to open gui")

	if self.selectedTeamData.name == "" or sm.SURVIVAL_EXTENSION.teams[self.selectedTeamData.name] == nil then
		return false
	end

	sm.gui.setInteractionText(
	"Press",
		sm.gui.getKeyBinding("Tinker", true),
		("to join: %s%s"):format(self.selectedTeamData.colour, self.selectedTeamData.name)
	)

	return true
end

function JoinGate:client_onInteract(character, state)
	if not sm.isHost or not state then
		return
	end

	self.gui = sm.gui.createGuiFromLayout(GUI_LAYOUT, false, { backgroundAlpha = 0.5 })

	self:cl_initCallback()

	self.sortedTeams = self:cl_getSortedTeams()
	self.maxPage = math.max(1, #self.sortedTeams)
	self.currentPage = math.min(self.currentPage, self.maxPage)

	self.gui:open()

	self:cl_updateSelectedTeam()
end

function JoinGate:client_onTinker(character, state)
	if not state then
		return
	end

	self.network:sendToServer("sv_setTeam", self.selectedTeamData.name)
end

function JoinGate:cl_onPageChanged(widgetName)
	local oldPage = self.currentPage

	if widgetName == "nextPage" then
		self.currentPage = math.min(self.currentPage + 1, self.maxPage)
	elseif widgetName == "prevPage" then
		self.currentPage = math.max(self.currentPage - 1, 1)
	end

	if oldPage ~= self.currentPage then
		self:cl_updateSelectedTeam()
	end
end

function JoinGate:cl_updateSelectedTeam()
	if #self.sortedTeams == 0 then
		self.selectedTeamName = ""
		return
	end

	local selectedName = self.sortedTeams[self.currentPage]
	self.selectedTeamName = selectedName

	self.gui:setText("TeamSelectedText", selectedName)
	self.gui:setText("currentPage", ("%s/%s"):format(self.currentPage, self.maxPage))
end

function JoinGate:cl_onApplyPressed()
	local teamData = sm.SURVIVAL_EXTENSION.teams[self.selectedTeamName]
	if teamData == nil then
		return
	end

	local newTeamData = {
		name = self.selectedTeamName,
		colour = teamData.colour,
	}

	self.network:sendToServer("sv_saveSelectedTeam", newTeamData)
end

function JoinGate:cl_getSortedTeams()
	local teams = {}
	if sm.SURVIVAL_EXTENSION and sm.SURVIVAL_EXTENSION.teams then
		for teamName, _ in pairs(sm.SURVIVAL_EXTENSION.teams) do
			table.insert(teams, teamName)
		end
		table.sort(teams)
	end
	return teams
end

function JoinGate:cl_onGuiCloseCallback()
	self:cl_destroyGui()
end

function JoinGate:cl_destroyGui()
	if self.gui and sm.exists(self.gui) then
		if self.gui:isActive() then
			self.gui:close()
		end
		self.gui:destroy()
	end

	self.gui = nil
end

function JoinGate:cl_initCallback()
	self.gui:setButtonCallback("nextPage", "cl_onPageChanged")
	self.gui:setButtonCallback("prevPage", "cl_onPageChanged")
	self.gui:setButtonCallback("applyButton", "cl_onApplyPressed")
	self.gui:setOnCloseCallback("cl_onGuiCloseCallback")
end
