---@diagnostic disable: undefined-field, undefined-doc-class, undefined-doc-name, cast-local-type, lowercase-global
---@class PlayerHook : ToolClass
PlayerHook = class()

dofile("$SURVIVAL_DATA/Scripts/game/managers/RespawnManager.lua")

local SAVEKEY = "38d8bd7e-e2d4-42cc-8f2b-5acb2b03fccd"
local SETTINGSPATH = "$CONTENT_DATA/presets.json"

local function loadPresets()
	if sm.json.fileExists(SETTINGSPATH) then
		return sm.json.open(SETTINGSPATH)
	end

	return {}
end

function sm.GetPlayerTeam(player)
	return (player.publicData or {}).survivalExtensionTeam
end

local function cl_GetPlayerTeam(player)
	return (player.clientPublicData or {}).survivalExtensionTeam
end

local function cl_GetPlayerTeamFull(player)
	local data = (player.clientPublicData or {})
	local team = data.survivalExtensionTeam
	if team then
		return ("[%s#ffffff] "):format(data.survivalExtensionTeamColour .. team)
	end

	return ""
end

local function GetTeamData(team)
	return sm.SURVIVAL_EXTENSION.teams[team] or { colour = "#ffffff" }
end

local function savePreset(presets, name)
	presets[name] = sm.SURVIVAL_EXTENSION
	sm.json.save(presets, SETTINGSPATH)
end

sm.SURVIVAL_EXTENSION_ruleToSyncToPlayers = {
	hunger = true,
	thirst = true,
	respawnCooldown = true,
}

function sm.SURVIVAL_EXTENSION_syncToPlayers(player)
	local data = {}
	for k, v in pairs(sm.SURVIVAL_EXTENSION_ruleToSyncToPlayers) do
		data[k] = sm.SURVIVAL_EXTENSION[k]
	end

	if player then
		sm.event.sendToPlayer(player, "sv_syncRules", data)
	else
		for _, player in pairs(sm.player.getAllPlayers()) do
			sm.event.sendToPlayer(player, "sv_syncRules", data)
		end
	end
end

local function isAnyOf(is, off)
	for _, v in pairs(off) do
		if is == v then
			return true
		end
	end

	return false
end

--set to empty table before loading
sm.SURVIVAL_EXTENSION = sm.SURVIVAL_EXTENSION or {}

function PlayerHook:server_onCreate()
	if sm.PLAYERHOOK then
		return
	end --avoid multiple loads

	local saved = self.storage:load() --sm.storage.load(SAVEKEY)
	sm.SURVIVAL_EXTENSION = saved
		or {
			pvp = true,
			health_regen = true,
			hunger = true,
			thirst = true,
			breath = true,
			spawn_hp = 100,
			spawn_water = 100,
			spawn_food = 100,
			collisionTumble = true,
			collisionDamage = true,
			godMode = false,
			dropItems = true,
			playerSpawns = {},
			teams = {},
			friendlyFire = false,
			respawnCooldown = 40,
			unSeatOnDamage = true,
			todCycle = false,
			todCycleLen = 24, -- minutes
			lastTod = 0.5,
			inventorySize = 30,
		}

	if not sm.SURVIVAL_EXTENSION.respawnCooldown then
		sm.SURVIVAL_EXTENSION.respawnCooldown = 40
	end

	if not sm.SURVIVAL_EXTENSION.unSeatOnDamage == nil then
		sm.SURVIVAL_EXTENSION.unSeatOnDamage = true
	end

	if not sm.SURVIVAL_EXTENSION.inventorySize then
		sm.SURVIVAL_EXTENSION.inventorySize = 30
	end

	self:sv_saveSettings()
	self:sv_registerCommandHandlers()

	sm.SURVIVAL_EXTENSION_syncToPlayers()

	g_respawnManager = RespawnManager()
	g_respawnManager:sv_onCreate(sm.world.getCurrentWorld())
	sm.RESPAWNMANAGER = g_respawnManager

	sm.PLAYERHOOK = self.tool
end

function PlayerHook:sv_saveSettings()
	self.storage:save(sm.SURVIVAL_EXTENSION)
	--sm.storage.save(SAVEKEY, sm.SURVIVAL_EXTENSION)
end

function PlayerHook:sv_saveAndChat(msg)
	self:sv_saveSettings()
	self:sv_chatMessage(msg)
end

function PlayerHook:sv_saveAndChat_single(player, msg)
	if type(player) == "table" then
		player, msg = player[1], player[2]
	end
	self:sv_saveSettings()
	self.network:sendToClient(player, "cl_chatMessage", msg)
end

function PlayerHook:sv_chatMessage(msg)
	self.network:sendToClients("cl_chatMessage", msg)
end

function PlayerHook:sv_chatMessage_single(player, msg)
	if type(player) == "table" then
		player, msg = player[1], player[2]
	end
	self.network:sendToClient(player, "cl_chatMessage", msg)
end

function PlayerHook:sv_OnPlayerDeathByPlayer(args)
	local attacker, victim = args.attacker, args.victim
	self.network:sendToClients(
		"cl_chatMessage",
		("%s #ffffffkilled %s#ffffff!"):format(
			GetTeamData(sm.GetPlayerTeam(attacker)).colour .. attacker:getName(),
			GetTeamData(sm.GetPlayerTeam(victim)).colour .. victim:getName()
		)
	)
end

function PlayerHook:sv_onUnknownPlayerDeath(args)
	---@type Player
	local victim = args.victim

	self.network:sendToClients(
		"cl_chatMessage",
		("%s #ffffffdied!"):format(GetTeamData(sm.GetPlayerTeam(victim)).colour .. victim:getName())
	)
end

local charIdToName = {
	["264a563a-e304-430f-a462-9963c77624e9"] = "Woc",
	["04761b4a-a83e-4736-b565-120bc776edb2"] = "Tapebot",
	["c3d31c47-0c9b-4b07-9bd4-8f022dc4333e"] = "Red Tapebot",
	["9dbbd2fb-7726-4e8f-8eb4-0dab228a561d"] = "Tapebot",
	["fcb2e8ce-ca94-45e4-a54b-b5acc156170b"] = "Tapebot",
	["68d3b2f3-ed4b-4967-9d22-8ee6f555df63"] = "Tapebot",
	["8984bdbf-521e-4eed-b3c4-2b5e287eb879"] = "Green Totebot",
	["c8bfb8f3-7efc-49ac-875a-eb85ac0614db"] = "Haybot",
	["9f4fde94-312f-4417-b13b-84029c5d6b52"] = "Farmbot",
	["48c03f69-3ec8-454c-8d1a-fa09083363b1"] = "Glowbug",
}

function PlayerHook:sv_OnPlayerDeathByUnit(args)
	---@type Player
	local victim = args.victim
	if not sm.exists(args.attacker) then
		self.network:sendToClients(
			"cl_chatMessage",
			("%s #ffffffkilled %s#ffffff!"):format(
				"Unknown unit",
				GetTeamData(sm.GetPlayerTeam(victim)).colour .. victim:getName()
			)
		)
		return
	end

	---@type Character
	local attacker = args.attacker.character
	self.network:sendToClients(
		"cl_chatMessage",
		("#%s #ffffffkilled %s#ffffff!"):format(
			attacker.color:getHexStr():sub(1, 6) .. (charIdToName[tostring(attacker:getCharacterType())] or "unknown"),
			GetTeamData(sm.GetPlayerTeam(victim)).colour .. victim:getName()
		)
	)
end

function PlayerHook:sv_handlePresetSave(args)
	local presets = loadPresets()
	local presetName = args[2]
	if presets[presetName] == nil then
		savePreset(presets, presetName)
		self:sv_chatMessage_single(args.player, ("SAVED '#df7f00%s#ffffff' PRESET"):format(presetName))
	else
		self.network:sendToClient(args.player, "cl_ConfirmOverwrite", presetName)
	end
end

function PlayerHook:sv_handlePresetLoad(args)
	local presets = loadPresets()
	local presetName = args[2]
	if presets[presetName] == nil then
		self:sv_chatMessage_single(
			args.player,
			("#ff0000NO PRESET BY THE NAME OF '#ffffff%s#ff0000' FOUND"):format(presetName)
		)
	else
		local preset = presets[presetName]
		preset.playerSpawns = preset.playerSpawns or {}
		preset.teams = preset.teams or {}
		for k, v in pairs(preset.teams) do
			v.players = v.players or {}
		end

		sm.SURVIVAL_EXTENSION = preset
		local text = ("LOADED '#df7f00%s#ffffff' PRESET:"):format(presetName)
		for name, setting in pairs(sm.SURVIVAL_EXTENSION) do
			local append = ""
			if name == "teams" and type(setting) == "table" then
				for team, teamData in pairs(setting) do
					local members = ""
					local players = teamData.players
					if #players == 0 then
						members = "No members"
					else
						for k, member in pairs(players) do
							members = members .. (k == #players and "%s" or "%s, "):format(member)
						end
					end

					append = append .. ("\n\t\t%s%s#ffffff:\n\t\t%s"):format(teamData.colour, team, members)
				end
			else
				append = setting
			end

			text = text .. ("#ffffff\n\t%s: #df7f00%s"):format(name, append)
		end

		local players = {}
		for k, v in pairs(sm.player.getAllPlayers()) do
			players[v:getName()] = v
		end

		for team, data in pairs(sm.SURVIVAL_EXTENSION.teams) do
			for k, member in pairs(data.players) do
				if players[member] then
					self:sv_setPlayerTeam({ players[member], team, data.colour })
				end
			end
		end

		if sm.SURVIVAL_EXTENSION.nameDisplayModeOverride then
			self:sv_setNameDisplayMode({ "hi", sm.SURVIVAL_EXTENSION.nameDisplayModeOverride, true })
		else
			self:sv_setNameDisplayMode({ "hi", 4, true })
		end

		self:sv_chatMessage_single(args.player, text)
		self:sv_saveSettings()
	end
end

function PlayerHook:sv_setPlayerTeam(args)
	self.network:sendToClients("cl_setPlayerTeam", args)
end

function PlayerHook:sv_setNameDisplayMode(args)
	local mode = args[2]

	if args[3] == true and mode ~= 4 then
		sm.SURVIVAL_EXTENSION.nameDisplayModeOverride = mode
	else
		sm.SURVIVAL_EXTENSION.nameDisplayModeOverride = nil
	end

	self:sv_saveSettings()

	if args[3] == true then
		self.network:sendToClients("cl_setNameDisplayMode", { mode, true })
		self:sv_forceUpdateAllNameTags(mode)
	else
		if g_cl_nameDisplayModeOverrideActive then
			self:sv_chatMessage_single(args[1], "#ff0000HOST HAS OVERRIDEN THE NAME DISPLAY MODE")
		else
			self.network:sendToClient(args[1], "cl_setNameDisplayMode", { mode, false })
		end
	end
end

function PlayerHook:sv_requestDataUpdate(_, caller)
	sm.SURVIVAL_EXTENSION_syncToPlayers(caller)

	local name = caller:getName()
	for team, teamData in pairs(sm.SURVIVAL_EXTENSION.teams) do
		if isAnyOf(name, teamData.players) then
			caller.publicData = {}
			caller.publicData.survivalExtensionTeam = team

			self:sv_setPlayerTeam({ caller, team, GetTeamData(team).colour })
			break
		end
	end

	if sm.SURVIVAL_EXTENSION.nameDisplayModeOverride then
		self:sv_setNameDisplayMode({ caller, sm.SURVIVAL_EXTENSION.nameDisplayModeOverride, true })
	end
end

function PlayerHook:sv_setWorldTime(time)
	self.network:sendToClients("cl_setWorldTime", time)
end

local nameDisplayModes = {
	"ALL",
	"TEAM",
	"NONE",
}

local overrideNameDisplayModes = {
	"ALL",
	"TEAM",
	"NONE",
	"NO OVERRIDE",
}

function PlayerHook:client_onCreate()
	if sm.PLAYERHOOKCLIENT then
		return
	end --avoid multiple loads

	if g_respawnManager == nil then
		assert(not sm.isHost)
		g_respawnManager = RespawnManager()
	end

	g_respawnManager:cl_onCreate()

	sm.PLAYERHOOKCLIENT = self.tool

	self.nameDisplayMode = 1

	g_cl_nameDisplayModeOverrideActive = false

	self:cl_setWorldTime(sm.SURVIVAL_EXTENSION.lastTod)

	self.network:sendToServer("sv_requestDataUpdate")
end

function PlayerHook:client_onFixedUpdate()
	if self.tool ~= sm.PLAYERHOOKCLIENT then
		return
	end

	---@type Player
	local localPlayer = sm.localPlayer.getPlayer()
	local localPlayerTeam = cl_GetPlayerTeam(localPlayer)
	local displayMode = self.nameDisplayModeOverride or self.nameDisplayMode
	for k, v in pairs(sm.player.getAllPlayers()) do
		local char = v.character
		if sm.exists(char) then
			if v == localPlayer or displayMode == 3 then
				char:setNameTag("")
				goto continue
			end

			local name = v:getName()
			if displayMode == 1 then
				char:setNameTag(cl_GetPlayerTeamFull(v) .. name)
			else
				char:setNameTag(localPlayerTeam == cl_GetPlayerTeam(v) and cl_GetPlayerTeamFull(v) .. name or "")
			end
		end

		::continue::
	end
end

function PlayerHook:cl_chatMessage(msg)
	sm.gui.chatMessage(msg)
end

function PlayerHook:cl_forceUpdateNameTag(mode)
	self.nameDisplayModeOverride = mode
	g_cl_nameDisplayModeOverrideActive = mode ~= 4
end

function PlayerHook:sv_forceUpdateAllNameTags(mode)
	self.network:sendToClients("cl_forceUpdateNameTag", mode)
end

function PlayerHook:cl_ConfirmOverwrite(name)
	self.presetName = name
	self.confirmGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout")
	self.confirmGui:setButtonCallback("Yes", "cl_onConfirmButtonClick")
	self.confirmGui:setButtonCallback("No", "cl_onConfirmButtonClick")
	self.confirmGui:setText("Title", "#{MENU_YN_TITLE_ARE_YOU_SURE}")
	self.confirmGui:setText("Message", ("This will overwrite the existing '#df7f00%s#919191' preset."):format(name))
	self.confirmGui:open()
end

function PlayerHook:cl_onConfirmButtonClick(name)
	if name == "Yes" then
		savePreset(loadPresets(), self.presetName)
	end

	self.confirmGui:close()
	self.confirmGui = nil
	self.presetName = nil
end

function PlayerHook:cl_setPlayerTeam(args)
	local player, team, teamColour = args[1], args[2], args[3]

	player.clientPublicData = player.clientPublicData or {}
	player.clientPublicData.survivalExtensionTeam = team
	player.clientPublicData.survivalExtensionTeamColour = teamColour

	if player == sm.localPlayer.getPlayer() then
		return
	end

	local name = player:getName()

	if team == nil then
		player.character:setNameTag(name)
		return
	end

	player.character:setNameTag(("[%s#ffffff] %s"):format(teamColour .. team, name))
end

function PlayerHook:cl_setNameDisplayMode(args)
	local mode, override = args[1], args[2]

	g_cl_nameDisplayModeOverrideActive = override and mode ~= 4
	if g_cl_nameDisplayModeOverrideActive then
		self.nameDisplayModeOverride = mode
		self:cl_chatMessage("#ff0000ENFORCED#ffffff NAME DISPLAY MODE: #df7f00" .. nameDisplayModes[mode])
	else
		if self.nameDisplayModeOverride or mode == 4 then
			self:cl_chatMessage(
				"OVERRIDE CLEARED, NAME DISPLAY MODE: #df7f00" .. nameDisplayModes[self.nameDisplayMode]
			)
			self.nameDisplayModeOverride = nil
		else
			self.nameDisplayMode = mode
			self:cl_chatMessage("NAME DISPLAY MODE: #df7f00" .. nameDisplayModes[mode])
		end
	end
end

function PlayerHook:cl_setWorldTime(time)
	sm.game.setTimeOfDay(time)
	sm.render.setOutdoorLighting(time)
end

local function toggleRule(rule, msg, value)
	local new = not sm.SURVIVAL_EXTENSION[rule]
	if value ~= nil then
		new = value
	end

	sm.SURVIVAL_EXTENSION[rule] = new

	if sm.SURVIVAL_EXTENSION_ruleToSyncToPlayers[rule] == true then
		sm.SURVIVAL_EXTENSION_syncToPlayers()
	end

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", msg .. (new and "#00ff00ON" or "#ff0000OFF"))
end

function PlayerHook:sv_sendAvailableTeams(player, errorMessage)
	local availableTeams = {}
	for k, v in pairs(sm.SURVIVAL_EXTENSION.teams) do
		table.insert(availableTeams, v.colour .. k)
	end
	local text = errorMessage .. " AVAILABLE TEAMS:\n\t" .. table.concat(availableTeams, "\n\t")
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { player, text })
end

function PlayerHook:sv_handleChatCommand(command, args)
	self:sv_registerCommandHandlers()

	local handler = self.commandHandlers[command]
	if handler then
		return handler(self, args)
	end
end

-- Command handlers with toggleRule
function PlayerHook:sv_handlePvpCommand(args)
	toggleRule("pvp", "PLAYER VS PLAYER: ", args[2])
end

function PlayerHook:sv_handleHealthRegenCommand(args)
	toggleRule("health_regen", "HEALTH REGENERATION: ", args[2])
end

function PlayerHook:sv_handleHungerCommand(args)
	toggleRule("hunger", "HUNGER: ", args[2])
end

function PlayerHook:sv_handleThirstCommand(args)
	toggleRule("thirst", "THIRST: ", args[2])
end

function PlayerHook:sv_handleBreathLossCommand(args)
	toggleRule("breath", "BREATH LOSS: ", args[2])
end

function PlayerHook:sv_handleCollisionTumbleCommand(args)
	toggleRule("collisionTumble", "COLLISION TUMBLE: ", args[2])
end

function PlayerHook:sv_handleCollisionDamageCommand(args)
	toggleRule("collisionDamage", "COLLISION DAMAGE: ", args[2])
end

function PlayerHook:sv_handleGodModeCommand(args)
	toggleRule("godMode", "GOD MODE: ", args[2])
end

function PlayerHook:sv_handleDropItemsCommand(args)
	toggleRule("dropItems", "DROP ITEMS UPON DEATH: ", args[2])
end

function PlayerHook:sv_handleFriendlyFireCommand(args)
	toggleRule("friendlyFire", "FRIENDLY FIRE: ", args[2])
end

function PlayerHook:sv_handleUnseatOnDamageCommand(args)
	toggleRule("unSeatOnDamage", "UNSEAT ON DAMAGE: ", args[2])
end

-- Special command handlers
function PlayerHook:sv_handleRespawnStatsCommand(args)
	local hp, water, food = args[2], args[3], args[4]
	sm.SURVIVAL_EXTENSION.spawn_hp = hp
	sm.SURVIVAL_EXTENSION.spawn_water = water
	sm.SURVIVAL_EXTENSION.spawn_food = food
	sm.event.sendToTool(
		sm.PLAYERHOOK,
		"sv_saveAndChat",
		("RESPAWN STATS: \n\tHP: #df7f00%s #ffffff\n\tWATER: #df7f00%s #ffffff\n\tFOOD: #df7f00%s"):format(
			hp,
			water,
			food
		)
	)
end

function PlayerHook:sv_handleCreativeInventoryCommand(args)
	local new = not sm.game.getLimitedInventory()
	sm.game.setLimitedInventory(new)
	sm.event.sendToTool(
		sm.PLAYERHOOK,
		"sv_chatMessage",
		"CREATIVE INVENTORY: " .. (not new and "#00ff00ON" or "#ff0000OFF")
	)
end

function PlayerHook:sv_handleAmmoConsumptionCommand(args)
	local new = not sm.game.getEnableAmmoConsumption()
	sm.game.setEnableAmmoConsumption(new)
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage", "AMMO CONSUMPTION: " .. (new and "#00ff00ON" or "#ff0000OFF"))
end

function PlayerHook:sv_handleSavePresetCommand(args)
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_handlePresetSave", args)
end

function PlayerHook:sv_handleLoadPresetCommand(args)
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_handlePresetLoad", args)
end

function PlayerHook:sv_handleSetSpawnCommand(args)
	local player = args.player
	local team = sm.SURVIVAL_EXTENSION.teams and sm.SURVIVAL_EXTENSION.teams[sm.GetPlayerTeam(player)]

	if team and not team.allowCustomSpawn then
		sm.event.sendToTool(
			sm.PLAYERHOOK,
			"sv_chatMessage_single",
			{ player, "Custom spawns are disabled for your team!" }
		)
		return
	end

	local worldPos = player.character.worldPosition
	sm.SURVIVAL_EXTENSION.playerSpawns[player.id] = worldPos
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat_single", {
		player,
		("SET SPAWN POINT TO: \n\t#ffffffx: #df7f00%s \n\t#ffffffy: #df7f00%s \n\t#ffffffz: #df7f00%s"):format(
			worldPos.x,
			worldPos.y,
			worldPos.z
		),
	})
end

function PlayerHook:sv_handleClearSpawnCommand(args)
	local player = args.player
	local team = sm.SURVIVAL_EXTENSION.teams and sm.SURVIVAL_EXTENSION.teams[sm.GetPlayerTeam(player)]

	if team and not team.allowCustomSpawn then
		sm.event.sendToTool(
			sm.PLAYERHOOK,
			"sv_chatMessage_single",
			{ player, "Spawn clearing is disabled for your team!" }
		)
		return
	end

	sm.SURVIVAL_EXTENSION.playerSpawns[player.id] = nil
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat_single", {
		player,
		"CLEARED SPAWN POINT",
	})
end

function PlayerHook:sv_handleCreateTeamCommand(args)
	local teamName, allow, teamColour = args[2], args[3], args[4]
	local finalColour = teamColour or "#888888"

	if teamColour then
		if finalColour:sub(1, 1) ~= "#" then
			finalColour = "#" .. finalColour
		end

		local padding = math.max(7 - #finalColour, 0)
		finalColour = finalColour .. string.rep("0", padding)

		finalColour = finalColour:sub(1, 7)
	end

	if sm.SURVIVAL_EXTENSION.teams[teamName] ~= nil then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
			args.player,
			("#ff0000TEAM '%s%s#ff0000' ALREADY EXISTS"):format(finalColour, teamName),
		})
		return
	end

	sm.SURVIVAL_EXTENSION.teams[teamName] = {
		colour = finalColour,
		players = {},
		spawnPoint = nil,
		allowCustomSpawn = allow,
	}

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", ("CREATED TEAM %s%s"):format(finalColour, teamName))
end

function PlayerHook:sv_handleDeleteTeamCommand(args)
	local teamName = args[2]
	if sm.SURVIVAL_EXTENSION.teams[teamName] == nil then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
			args.player,
			("#ff0000TEAM '#ffffff%s#ff0000' DOESN'T EXIST"):format(teamName),
		})
		return
	end

	for k, v in pairs(sm.player.getAllPlayers()) do
		if (v.publicData or {}).survivalExtensionTeam == teamName then
			v.publicData.survivalExtensionTeam = nil
			sm.event.sendToTool(sm.PLAYERHOOK, "sv_setPlayerTeam", { v })
		end
	end

	sm.SURVIVAL_EXTENSION.teams[teamName] = nil
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", ("DELETED TEAM %s"):format(teamName))
end

function PlayerHook:sv_handleSetTeamCommand(args)
	local player, team = args.player, args[2]
	local teamData = sm.SURVIVAL_EXTENSION.teams[team]

	if not teamData then
		self:sv_sendAvailableTeams(player, "#ff0000TEAM NOT FOUND#ffffff")
		return
	end

	player.publicData = player.publicData or {}
	local prevTeam = player.publicData.survivalExtensionTeam

	if prevTeam == team then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
			player,
			"#ff0000YOU ARE ALREADY A MEMBER OF THIS TEAM",
		})
		return
	end

	local name = player:getName()

	if prevTeam then
		for i, v in pairs(sm.SURVIVAL_EXTENSION.teams[prevTeam].players) do
			if v == name then
				table.remove(sm.SURVIVAL_EXTENSION.teams[prevTeam].players, i)
				break
			end
		end
	end

	player.publicData.survivalExtensionTeam = team
	sm.SURVIVAL_EXTENSION.playerSpawns[player.id] = teamData.spawnPoint or sm.SURVIVAL_EXTENSION.playerSpawns[player.id]

	if not isAnyOf(name, teamData.players) then
		table.insert(teamData.players, name)
	end

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_setPlayerTeam", { player, team, teamData.colour })
	sm.event.sendToTool(
		sm.PLAYERHOOK,
		"sv_saveAndChat",
		("%s JOINED TEAM '%s%s#ffffff'"):format(name, teamData.colour, team)
	)

	for _, otherPlayer in pairs(sm.player.getAllPlayers()) do
		if otherPlayer ~= player then
			local otherTeam = sm.GetPlayerTeam(otherPlayer)
			if otherTeam and sm.SURVIVAL_EXTENSION.teams[otherTeam] then
				local colour = sm.SURVIVAL_EXTENSION.teams[otherTeam].colour
				sm.event.sendToTool(sm.PLAYERHOOK, "sv_setPlayerTeam", { otherPlayer, otherTeam, colour })
			end
		end
	end
end

function PlayerHook:sv_handleClearTeamCommand(args)
	local player = args.player
	local prevTeam = sm.GetPlayerTeam(player) or {}

	if not prevTeam then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
			args.player,
			"#ff0000NO TEAM SET",
		})
		return
	end

	player.publicData.survivalExtensionTeam = nil
	sm.SURVIVAL_EXTENSION.playerSpawns[player.id] = nil

	local name = player:getName()
	for i, v in pairs(sm.SURVIVAL_EXTENSION.teams[prevTeam].players) do
		if v == name then
			table.remove(sm.SURVIVAL_EXTENSION.teams[prevTeam].players, i)
			break
		end
	end

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_setPlayerTeam", { player })
	sm.event.sendToTool(
		sm.PLAYERHOOK,
		"sv_saveAndChat",
		("%s LEFT '%s%s#ffffff'"):format(name, sm.SURVIVAL_EXTENSION.teams[prevTeam].colour, prevTeam)
	)
end

function PlayerHook:sv_handleListTeamsCommand(args)
	local text = "AVAILABLE TEAMS:"
	for k, v in pairs(sm.SURVIVAL_EXTENSION.teams) do
		text = text .. ("\n\t%s"):format(v.colour .. k)
	end
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { args.player, text })
end

function PlayerHook:sv_handleRespawnCooldownCommand(args)
	local seconds = math.abs(args[2])
	sm.SURVIVAL_EXTENSION.respawnCooldown = seconds * 40
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", ("RESPAWN COOLDOWN SET TO: #df7f00%s seconds"):format(seconds))
	sm.SURVIVAL_EXTENSION_syncToPlayers()
end

function PlayerHook:sv_handleDisplayNamesCommand(args)
	local mode = tonumber(args[2])
	if not mode or mode < 1 or mode > #overrideNameDisplayModes then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
			args.player,
			("#ff0000MODE ID MUST BE A NUMBER BETWEEN '#ffffff1#ff0000' and '#ffffff%s#ff0000'"):format(
				#overrideNameDisplayModes
			),
		})
		return
	end

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_setNameDisplayMode", { args.player, mode, true })
end

function PlayerHook:sv_handleClearAllInventoriesCommand(args)
	local players = sm.player.getAllPlayers()
	local nilUuid = sm.uuid.getNil()
	local oldLimited = sm.game.getLimitedInventory()

	sm.game.setLimitedInventory(true)
	for _, player in ipairs(players) do
		local inventory = player:getInventory()

		if sm.exists(inventory) then
			local attempts = 0
			local maxAttempts = 3

			while not inventory:isEmpty() and attempts < maxAttempts do
				if sm.container.beginTransaction() then
					for i = 0, inventory:getSize() - 1 do
						local item = inventory:getItem(i)

						if not item.uuid:isNil() then
							sm.container.setItem(inventory, i, nilUuid, 0)
						end
					end

					sm.container.endTransaction()
				end

				attempts = attempts + 1
			end
		end
	end
	sm.game.setLimitedInventory(oldLimited)

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage", "ALL INVENTORIES CLEARED!")
end

function PlayerHook:sv_handleSetTeamSpawnPointCommand(args)
	local teamName = args[2]
	local teamData = sm.SURVIVAL_EXTENSION.teams[teamName]

	if not teamData then
		self:sv_sendAvailableTeams(args.player, "#ff0000TEAM NOT FOUND#ffffff")
		return
	end

	local player = args.player
	local worldPos = player.character.worldPosition
	local messageFormat =
		"TEAM: %s%s#ffffff SPAWN SET: \n\t#ffffffx: #df7f00%s \n\t#ffffffy: #df7f00%s \n\t#ffffffz: #df7f00%s"
	local formattedMessage = messageFormat:format(teamData.colour, teamName, worldPos.x, worldPos.y, worldPos.z)

	teamData.spawnPoint = worldPos

	local teamPlayersMap = {}
	for _, teamPlayer in ipairs(sm.player.getAllPlayers()) do
		teamPlayersMap[teamPlayer:getName()] = teamPlayer
	end

	for _, teamPlayerName in ipairs(teamData.players) do
		local teamPlayer = teamPlayersMap[teamPlayerName]
		if teamPlayer then
			sm.SURVIVAL_EXTENSION.playerSpawns[teamPlayer.id] = worldPos
			sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { teamPlayer, formattedMessage })
		end
	end

	if not isAnyOf(player:getName(), teamData.players) then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { player, formattedMessage })
	end
end

function PlayerHook:sv_handleClearTeamSpawnPointCommand(args)
	local teamName = args[2]
	local teamData = sm.SURVIVAL_EXTENSION.teams[teamName]

	if not teamData then
		self:sv_sendAvailableTeams(args.player, "#ff0000TEAM NOT FOUND#ffffff")
		return
	end

	teamData.spawnPoint = nil

	local teamPlayersMap = {}
	for _, teamPlayer in ipairs(sm.player.getAllPlayers()) do
		teamPlayersMap[teamPlayer:getName()] = teamPlayer
	end

	local clearMessage = ("TEAM: %s%s#ffffff SPAWN CLEARED"):format(teamData.colour, teamName)

	for _, teamPlayerName in ipairs(teamData.players) do
		local teamPlayer = teamPlayersMap[teamPlayerName]
		if teamPlayer then
			sm.SURVIVAL_EXTENSION.playerSpawns[teamPlayer.id] = nil
			sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { teamPlayer, clearMessage })
		end
	end

	if not isAnyOf(args.player:getName(), teamData.players) then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { args.player, clearMessage })
	end
end

function PlayerHook:sv_handleKillCommand(args)
	local character = args.player:getCharacter()

	if sm.SURVIVAL_EXTENSION.godMode then
		sm.event.sendToTool(
			sm.PLAYERHOOK,
			"sv_chatMessage_single",
			{ args.player, "#ff0000TURN OFF GOD MODE: #ffffff/godmode" }
		)
		return
	end

	if character and sm.exists(character) then
		sm.event.sendToPlayer(args.player, "sv_takeDamage", {
			damage = 100,
			source = "shock",
			attacker = nil,
		})
	end
end

function PlayerHook:sv_handleRenameTeamCommand(args)
	local oldTeamName = args[2]
	local newTeamName = args[3]

	if sm.SURVIVAL_EXTENSION.teams[oldTeamName] == nil then
		sm.event.sendToTool(
			sm.PLAYERHOOK,
			"sv_chatMessage_single",
			{ args.player, "#FF0000ERROR: TEAM NOT FOUND: " .. tostring(oldTeamName) }
		)
		return
	end

	if sm.SURVIVAL_EXTENSION.teams[newTeamName] ~= nil then
		sm.event.sendToTool(
			sm.PLAYERHOOK,
			"sv_chatMessage_single",
			{ args.player, "#FF0000ERROR: NAME ALREADY TAKEN!" }
		)
		return
	end

	sm.SURVIVAL_EXTENSION.teams[newTeamName] = sm.SURVIVAL_EXTENSION.teams[oldTeamName]
	sm.SURVIVAL_EXTENSION.teams[oldTeamName] = nil

	local teamData = sm.SURVIVAL_EXTENSION.teams[newTeamName]

	local playersInTeam = {}
	for _, name in ipairs(teamData.players) do
		playersInTeam[name] = true
	end

	for _, player in pairs(sm.player.getAllPlayers()) do
		if playersInTeam[player.name] then
			sm.event.sendToTool(sm.PLAYERHOOK, "sv_setPlayerTeam", { player, newTeamName, teamData.colour })

			player.publicData.survivalExtensionTeam = newTeamName
			sm.SURVIVAL_EXTENSION.playerSpawns[player.id] = teamData.spawnPoint or sm.SURVIVAL_EXTENSION.playerSpawns[player.id]
		end
	end

	sm.event.sendToTool(
		sm.PLAYERHOOK,
		"sv_saveAndChat_single",
		{
			args.player,
			("TEAM %s%s #FFFFFFRENAMED TO %s%s"):format(teamData.colour, oldTeamName, teamData.colour, newTeamName),
		}
	)
end

-- function PlayerHook:sv_handleTodCycleCommand(args)
-- 	local dayLen = args[2]

-- 	if dayLen then
-- 		sm.SURVIVAL_EXTENSION.todCycleLen = dayLen
-- 		sm.SURVIVAL_EXTENSION.todCycle = true
-- 	else
-- 		sm.SURVIVAL_EXTENSION.todCycle = not sm.SURVIVAL_EXTENSION.todCycle
-- 	end

-- 	sm.SURVIVAL_EXTENSION.lastTod = sm.game.getTimeOfDay()

-- 	local msg = "TOD CYCLE: "
-- 		.. (
-- 			sm.SURVIVAL_EXTENSION.todCycle
-- 				and ("#00ff00ON #ffffff(Day Length: %.2f min)"):format(sm.SURVIVAL_EXTENSION.todCycleLen)
-- 			or "#ff0000OFF"
-- 		)

-- 	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", msg)
-- end

function PlayerHook:sv_handleTodCommand(args)
	local time = sm.util.clamp(args[2], 0, 1)

	sm.SURVIVAL_EXTENSION.lastTod = time
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_setWorldTime", time)
	sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", ("Time of Day set to %.2f"):format(time))
end

function PlayerHook:sv_handleListPlayersCommand(args)
	local text = "AVAILABLE PLAYERS:"

	local players = sm.player.getAllPlayers()

	table.sort(players, function(a, b)
		return a.id < b.id
	end)

	for _, player in ipairs(players) do
		local team = (player.publicData or {}).survivalExtensionTeam

		local colour = "#ffffff"
		local teamInfo = ""

		if team then
			local teamData = GetTeamData(team)
			colour = teamData.colour
			teamInfo = ("\tTeam: %s%s"):format(colour, team)
		end

		text = text .. ("\n\t#ffffffName: %s%s#ffffff\tId: %s%s"):format(colour, player.name, player.id, teamInfo)
	end

	sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { args.player, text })
end

function PlayerHook:sv_handleTeleportCommand(args)
	local player = args.player
	local targetName = string.lower(args[2])
	local foundPlayers = {}

	for _, p in ipairs(sm.player.getAllPlayers()) do
		local playerName = string.lower(p:getName())

		if playerName == targetName then
			foundPlayers = { p }
			break
		end

		if string.find(playerName, targetName, 1, true) then
			table.insert(foundPlayers, p)
		end
	end

	if #foundPlayers == 0 then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { player, "NOT FOUND." })
		return
	elseif #foundPlayers > 1 then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { player, "MULTIPLE FOUND." })
		return
	end

	local targetPlayer = foundPlayers[1]

	if targetPlayer == player then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { player, "CAN'T TP TO SELF." })
		return
	end

	---@type Character
	local myCharacter = player:getCharacter()
	---@type Character
	local targetCharacter = targetPlayer:getCharacter()

	if sm.exists(myCharacter) and sm.exists(targetCharacter) then
		myCharacter:setWorldPosition(targetCharacter:getWorldPosition())
	end
end

function PlayerHook:sv_handleInventorySizeCommand(args)
	local size = args[2]
	if size > 30 then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { args.player, "#ff0000MAX SIZE IS 30" })
		size = 30
	elseif size < 1 then
		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", { args.player, "#ff0000MIN SIZE IS 1" })
		size = 1
	end

	sm.SURVIVAL_EXTENSION.inventorySize = size
	sm.event.sendToTool(
		sm.PLAYERHOOK,
		"sv_saveAndChat_single",
		{ args.player, ("DEFAULT INVENTORY SIZE: 30\nINVENTORY SIZE SET TO: %s"):format(size) }
	)
end

-- function PlayerHook:sv_handleDistributePlayersCommand(args)
-- 	local numTeams = args[2]
-- 	local createNewTeams = args[3]
-- 	local allPlayers = sm.player.getAllPlayers()

-- 	if #allPlayers < numTeams then
-- 		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
-- 			args.player,
-- 			"#ff0000NOT ENOUGH PLAYERS TO DISTRIBUTE INTO " .. numTeams .. " TEAMS",
-- 		})
-- 		return
-- 	end

-- 	-- if numTeams < 1 then
-- 	-- 	sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
-- 	-- 		args.player,
-- 	-- 		"#ff0000NUMBER OF TEAMS MUST BE AT LEAST 1",
-- 	-- 	})
-- 	-- 	return
-- 	-- end

-- 	if createNewTeams == nil then
-- 		createNewTeams = false
-- 	end

-- 	local newTeams = {}

-- 	if createNewTeams then
-- 		local defaultColours = { "#ff0000", "#0000ff", "#00ff00", "#ffff00", "#ff00ff", "#00ffff" }

-- 		for i = 1, numTeams do
-- 			local teamName = "Team" .. i
-- 			local hexColor = defaultColours[i] or "#888888"

-- 			newTeams[teamName] = {
-- 				colour = hexColor,
-- 				players = {},
-- 				spawnPoint = nil,
-- 				allowCustomSpawn = false,
-- 			}

			
-- 		end

-- 		sm.event.sendToTool(sm.PLAYERHOOK, "sv_saveAndChat", "#ffff00CREATED " .. numTeams .. " NEW TEAMS")
-- 	else
-- 		for _, teamData in pairs(sm.SURVIVAL_EXTENSION.teams) do
-- 			teamData.players = {}
-- 		end
-- 	end

-- 	local availableTeams = {}
-- 	for teamName, _ in pairs(sm.SURVIVAL_EXTENSION.teams) do
-- 		table.insert(availableTeams, teamName)
-- 	end

-- 	if #availableTeams == 0 then
-- 		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
-- 			args.player,
-- 			"#ff0000NO TEAMS AVAILABLE, CREATE SOME WITH /createteam [name]",
-- 		})
-- 		return
-- 	end

-- 	table.shuffle(allPlayers)

-- 	for index, player in ipairs(allPlayers) do
-- 		local teamIndex = ((index - 1) % #availableTeams) + 1
-- 		local targetTeamName = availableTeams[teamIndex]
-- 		local teamData = sm.SURVIVAL_EXTENSION.teams[targetTeamName]
-- 		local playerName = player:getName()

-- 		sm.SURVIVAL_EXTENSION.playerSpawns[player.id] = teamData.spawnPoint or nil

-- 		table.insert(teamData.players, playerName)

-- 		player.publicData = player.publicData or {}
-- 		player.publicData.survivalExtensionTeam = targetTeamName

-- 		sm.event.sendToTool(sm.PLAYERHOOK, "sv_setPlayerTeam", { player })

-- 		sm.event.sendToTool(sm.PLAYERHOOK, "sv_chatMessage_single", {
-- 			player,
-- 			("#ffffffYou were assigned to %s%s"):format(teamData.colour, targetTeamName),
-- 		})
-- 	end
-- end

-- [[local gameHooked = false
-- local oldHud = sm.gui.createSurvivalHudGui
-- function hudHook()
--     if not gameHooked then
--         gameHooked = true
--         dofile("$CONTENT_DATA/Scripts/vanilla_override.lua")
--     end

-- 	return oldHud()
-- end
-- sm.gui.createSurvivalHudGui = hudHook]]

local commands = {
	{
		name = "pvp",
		description = "Toggle pvp",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "healthReg",
		description = "Toggle health regeneration",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "hunger",
		description = "Toggle hunger",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "thirst",
		description = "Toggle thirst",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "breathLoss",
		description = "Toggle breath loss underwater",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "respawnStats",
		description = "Set the stats that the player receives upon respawning",
		args = {
			{ "number", "hp", false },
			{ "number", "water", false },
			{ "number", "food", false },
		},
	},

	{
		name = "creativeInventory",
		description = "Toggles the creative inventory",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "collisionTumble",
		description = "Toggles collision tumble",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "collisionDamage",
		description = "Toggles collision damage",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "godMode",
		description = "Toggles god mode",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "savePreset",
		description = "Saves the settings to a preset",
		args = {
			{ "string", "presetName", false },
		},
	},

	{
		name = "loadPreset",
		description = "Loads the settings from a preset",
		args = {
			{ "string", "presetName", false },
		},
	},

	{
		name = "dropItems",
		description = "Toggles whether or not items are dropped upon death",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "ammoConsumption",
		description = "Toggles the ammo consumption",
		args = {
			{ "bool", "enable", true },
		},
	},

	{ name = "setSpawn", description = "Sets the spawn point(beds override it)", all = true },

	{ name = "clearSpawn", description = "Clears the spawn point", all = true },

	{
		name = "createTeam",
		description = "Creates a team",
		args = {
			{ "string", "teamName", false },
			{ "bool", "allowCustomSpawn", true },
			{ "string", "teamColor(hex code)", true },
		},
	},

	{
		name = "deleteTeam",
		description = "Deletes a team",
		args = {
			{ "string", "teamName", false },
		},
	},

	{
		name = "setTeam",
		description = "Sets your team",
		args = {
			{ "string", "teamName", false },
		},
		all = true,
	},

	{
		name = "clearTeam",
		description = "Clears your team",
		all = true,
	},

	{
		name = "listTeams",
		description = "Lists all the available teams",
		args = {},
		all = true,
	},

	{
		name = "friendlyFire",
		description = "Toggles friendly fire",
		args = {
			{ "bool", "enable", true },
		},
	},

	{
		name = "displayNames",
		description = "Sets the display mode of player names for all palyers",
		args = {
			{ "int", "mode(1-all/2-team/3-none/4-no override)", true },
		},
		all = false,
	},

	{
		name = "respawnCooldown",
		description = "Sets the respawn cooldown",
		args = {
			{ "int", "cooldown(seconds)", false },
		},
	},

	{
		name = "unSeatOnDamage",
		description = "Toggles whether the player gets knocked out of their seat upon taking damage",
		args = {
			{ "bool", "enable", true },
		},
	},

	{ name = "clearInventories", description = "Remove all items from every player's inventory" },

	{
		name = "setTeamSpawn",
		description = "Set team-specific spawn location using your current position",
		args = {
			{ "string", "teamName", false },
		},
	},

	{
		name = "clearTeamSpawn",
		description = "Remove custom spawn point for a team",
		args = {
			{ "string", "teamName", false },
		},
	},

	{ name = "kill", description = "Kills the player character instantly", all = true },

	{
		name = "renameTeam",
		description = "",
		args = {
			{ "string", "targetTeamName", false },
			{ "string", "newTeamName", false },
		},
	},

	-- {
	-- 	name = "todCycle",
	-- 	description = "Toggles and sets the speed of the day/night cycle",
	-- 	args = {
	-- 		{ "number", "cycleMins", true },
	-- 	},
	-- },

	{
		name = "tod",
		description = "Sets the time of day",
		args = {
			{ "number", "time", false },
		},
	},

	{ name = "listPlayers", description = "Lists all players", all = true },

	{
		name = "tp",
		description = "Teleport to player by name (partial names accepted, but must be unique)",
		args = {
			{ "string", "targetPlayerName", false },
		},
		all = true,
	},

	{
		name = "inventorySize",
		description = "Sets the inventory size for all players (with limited inventory only)",
		args = { { "int", "size", false } },
	},

	-- {
	-- 	name = "splitPlayers",
	-- 	description = "Randomly split players into a specified number of teams, with an option to create new teams or use existing ones",
	-- 	args = {
	-- 		{ "int", "numTeams", false },
	-- 		{ "bool", "createNewTeams", true },
	-- 	},
	-- },
}

function PlayerHook:sv_registerCommandHandlers()
	if self.commandHandlers then
		return
	end

	self.commandHandlers = {
		["/pvp"] = self.sv_handlePvpCommand,
		["/healthreg"] = self.sv_handleHealthRegenCommand,
		["/hunger"] = self.sv_handleHungerCommand,
		["/thirst"] = self.sv_handleThirstCommand,
		["/breathloss"] = self.sv_handleBreathLossCommand,
		["/respawnstats"] = self.sv_handleRespawnStatsCommand,
		["/creativeinventory"] = self.sv_handleCreativeInventoryCommand,
		["/collisiontumble"] = self.sv_handleCollisionTumbleCommand,
		["/collisiondamage"] = self.sv_handleCollisionDamageCommand,
		["/godmode"] = self.sv_handleGodModeCommand,
		["/savepreset"] = self.sv_handleSavePresetCommand,
		["/loadpreset"] = self.sv_handleLoadPresetCommand,
		["/dropitems"] = self.sv_handleDropItemsCommand,
		["/ammoconsumption"] = self.sv_handleAmmoConsumptionCommand,
		["/setspawn"] = self.sv_handleSetSpawnCommand,
		["/clearspawn"] = self.sv_handleClearSpawnCommand,
		["/createteam"] = self.sv_handleCreateTeamCommand,
		["/deleteteam"] = self.sv_handleDeleteTeamCommand,
		["/setteam"] = self.sv_handleSetTeamCommand,
		["/clearteam"] = self.sv_handleClearTeamCommand,
		["/listteams"] = self.sv_handleListTeamsCommand,
		["/friendlyfire"] = self.sv_handleFriendlyFireCommand,
		["/respawncooldown"] = self.sv_handleRespawnCooldownCommand,
		["/unseatondamage"] = self.sv_handleUnseatOnDamageCommand,
		["/displaynames"] = self.sv_handleDisplayNamesCommand,
		["/clearinventories"] = self.sv_handleClearAllInventoriesCommand,
		["/setteamspawn"] = self.sv_handleSetTeamSpawnPointCommand,
		["/clearteamspawn"] = self.sv_handleClearTeamSpawnPointCommand,
		["/kill"] = self.sv_handleKillCommand,
		["/renameteam"] = self.sv_handleRenameTeamCommand,
		-- ["/todcycle"] = self.sv_handleTodCycleCommand,
		["/tod"] = self.sv_handleTodCommand,
		["/listplayers"] = self.sv_handleListPlayersCommand,
		["/tp"] = self.sv_handleTeleportCommand,
		["/inventorysize"] = self.sv_handleInventorySizeCommand,
		-- ["/splitplayers"] = self.sv_handleDistributePlayersCommand,
	}
end

oldBind = oldBind or sm.game.bindChatCommand
function bindHook(command, params, callback, help)
	if not gameHooked then
		gameHooked = true

		for k, v in pairs(commands) do
			if v.all or sm.isHost then
				oldBind("/" .. v.name:lower(), v.args or {}, "cl_onChatCommand", v.description)
			end
		end

		dofile("$CONTENT_24fc65a7-e1aa-4b66-86bc-d8229df53981/Scripts/vanilla_override.lua")
	end

	return oldBind(command, params, callback, help)
end

sm.game.bindChatCommand = bindHook

oldWorldEvent = oldWorldEvent or sm.event.sendToWorld
function worldEventHook(world, callback, args)
	-- sm.log.warning("WORLD EVENT HOOK:", world, callback, args)

	if callback == "sv_e_onChatCommand" then
		PlayerHook:sv_handleChatCommand(args[1], args)
	end

	return oldWorldEvent(world, callback, args)
end

sm.event.sendToWorld = worldEventHook
