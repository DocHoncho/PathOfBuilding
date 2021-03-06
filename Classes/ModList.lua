-- Path of Building
--
-- Module: Mod List
-- Stores modifiers in a flat list
--
local launch, main = ...

local pairs = pairs
local t_insert = table.insert
local m_floor = math.floor
local m_abs = math.abs
local band = bit.band
local bor = bit.bor

local mod_createMod = modLib.createMod

local hack = { }

local ModListClass = common.NewClass("ModList", function(self)
	self.multipliers = { }
	self.conditions = { }
	self.stats = { }
end)

function ModListClass:AddMod(mod)
	t_insert(self, mod)
end

function ModListClass:AddList(modList)
	for i = 1, #modList do
		t_insert(self, modList[i])
	end
end

function ModListClass:CopyList(modList)
	for i = 1, #modList do
		self:AddMod(copyTable(modList[i]))
	end
end

function ModListClass:ScaleAddList(modList, scale)
	for i = 1, #modList do
		local scaledMod = copyTable(modList[i])
		if type(scaledMod.value) == "number" then
			scaledMod.value = (m_floor(scaledMod.value) == scaledMod.value) and m_floor(scaledMod.value * scale) or scaledMod.value * scale
		end
		self:AddMod(scaledMod)
	end
end

function ModListClass:NewMod(...)
	self:AddMod(mod_createMod(...))
end

function ModListClass:Sum(modType, cfg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
	local flags, keywordFlags = 0, 0
	local skillName, skillGem, skillPart, skillTypes, slotName, source, tabulate
	if cfg then
		flags = cfg.flags or 0
		keywordFlags = cfg.keywordFlags or 0
		skillName = cfg.skillName
		skillGem = cfg.skillGem
		skillPart = cfg.skillPart
		skillTypes = cfg.skillTypes
		slotName = cfg.slotName
		source = cfg.source
		tabulate = cfg.tabulate
	end
	local result
	local nullValue = 0
	if tabulate or modType == "LIST" then
		result = { }
		nullValue = nil
	elseif modType == "MORE" then
		result = 1
	elseif modType == "FLAG" then
		result = false
		nullValue = false
	else
		result = 0
	end
	hack[1] = arg1
	if arg1 then
		hack[2] = arg2
		if arg2 then
			hack[3] = arg3
			if arg3 then
				hack[4] = arg4
				if arg4 then
					hack[5] = arg5
					if arg5 then
						hack[6] = arg6
						if arg6 then
							hack[7] = arg7
							if arg7 then
								hack[8] = arg8
								if arg8 then
									hack[9] = arg9
									if arg9 then
										hack[10] = arg10
										if arg10 then
											hack[11] = arg11
											if arg11 then
												hack[12] = arg12
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	for i = 1, #hack do --i = 1, select('#', ...) do
		local modName = hack[i]--select(i, ...)
		for i = 1, #self do
			local mod = self[i]
			if mod.name == modName and (not modType or mod.type == modType) and band(flags, mod.flags) == mod.flags and (mod.keywordFlags == 0 or band(keywordFlags, mod.keywordFlags) ~= 0) and (not source or mod.source:match("[^:]+") == source) then
				local value = mod.value
				for _, tag in pairs(mod.tagList) do
					if tag.type == "Multiplier" then
						local mult = (self.multipliers[tag.var] or 0)
						if type(value) == "table" then
							value = copyTable(value)
							value.value = value.value * mult + (tag.base or 0)
						else
							value = value * mult + (tag.base or 0)
						end
					elseif tag.type == "PerStat" then
						local mult = m_floor((self.stats[tag.stat] or 0) / tag.div + 0.0001)
						if type(value) == "table" then
							value = copyTable(value)
							value.value = value.value * mult + (tag.base or 0)
						else
							value = value * mult + (tag.base or 0)
						end
					elseif tag.type == "Condition" then
						local match = false
						if tag.varList then
							for _, var in pairs(tag.varList) do
								if self.conditions[var] then
									match = true
									break
								end
							end
						else
							match = self.conditions[tag.var]
						end
						if tag.neg then
							match = not match
						end
						if not match then
							value = nullValue
							break
						end
					elseif tag.type == "SocketedIn" then
						if tag.slotName ~= slotName or (tag.keyword and (not skillGem or not gemIsType(skillGem, tag.keyword))) then
							value = nullValue
							break
						end
					elseif tag.type == "SkillName" then
						if tag.skillName ~= skillName then
							value = nullValue
							break
						end
					elseif tag.type == "SkillPart" then
						if tag.skillPart ~= skillPart then
							value = nullValue
							break
						end
					elseif tag.type == "SkillType" then
						if not skillTypes or not skillTypes[tag.skillType] then
							value = nullValue
							break
						end
					elseif tag.type == "SlotName" then
						if tag.slotName ~= slotName then
							value = nullValue
							break
						end
					end
				end
				if tabulate then
					if value and value ~= 0 then
						t_insert(result, { value = value, mod = mod })
					end
				elseif modType == "MORE" then
					result = result * (1 + value / 100)
				elseif modType == "FLAG" then
					result = result or value
				elseif modType == "LIST" then
					if value then
						t_insert(result, value)
					end
				else
					result = result + value
				end
			end
		end
		hack[i] = nil
	end
	return result
end

function ModListClass:Print()
	for _, mod in ipairs(self) do
		ConPrintf("%s|%s", modLib.formatMod(mod), mod.source or "?")
	end
end
