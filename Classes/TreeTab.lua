-- Path of Building
--
-- Module: Tree Tab
-- Passive skill tree tab for the current build.
--
local launch, main = ...

local ipairs = ipairs
local t_insert = table.insert
local m_min = math.min

local TreeTabClass = common.NewClass("TreeTab", "ControlHost", function(self, build)
	self.ControlHost()

	self.build = build

	self.viewer = common.New("PassiveTreeView")

	self.specList = { }
	self.specList[1] = common.New("PassiveSpec", build)
	self:SetActiveSpec(1)

	self.anchorControls = common.New("Control", nil, 0, 0, 0, 20)
	--[[self.controls.specSelect = common.New("DropDownControl", {"LEFT",self.anchorControls,"RIGHT"}, 0, 0, 150, 20, nil, function(sel)
		if self.specList[sel] then
			self:SetActiveSpec(sel)
		else
			self:OpenSpecManagePopup()
		end
	end)]]
	--self.controls.reset = common.New("ButtonControl", {"LEFT",self.controls.specSelect,"RIGHT"}, 8, 0, 60, 20, "Reset", function()
	self.controls.reset = common.New("ButtonControl", {"LEFT",self.anchorControls,"RIGHT"}, 0, 0, 60, 20, "Reset", function()
		main:OpenConfirmPopup("Reset Tree", "Are you sure you want to reset your passive tree?", "Reset", function()
			self.build.spec:ResetNodes()
			self.build.spec:AddUndoState()
			self.build.buildFlag = true
		end)
	end)
	self.controls.import = common.New("ButtonControl", {"LEFT",self.controls.reset,"RIGHT"}, 8, 0, 90, 20, "Import Tree", function()
		self:OpenImportPopup()
	end)
	self.controls.export = common.New("ButtonControl", {"LEFT",self.controls.import,"RIGHT"}, 8, 0, 90, 20, "Export Tree", function()
		self:OpenExportPopup()
	end)
	self.controls.treeSearch = common.New("EditControl", {"LEFT",self.controls.export,"RIGHT"}, 8, 0, 300, 20, "", "Search", "%c%(%)", 100, function(buf)
		self.viewer.searchStr = buf
	end)
	self.controls.treeHeatMap = common.New("CheckBoxControl", {"LEFT",self.controls.treeSearch,"RIGHT"}, 130, 0, 20, "Show node power:", function(state)	
		self.viewer.showHeatMap = state
	end)
	self.controls.treeHeatMap.tooltip = "When enabled, an estimate of the offensive and defensive strength of\neach unallocated passive is calculated and displayed visually.\nOffensive power shows as red, defensive power as blue."
end)

function TreeTabClass:Draw(viewPort, inputEvents)
	self.anchorControls.x = viewPort.x + 4
	self.anchorControls.y = viewPort.y + viewPort.height - 24

	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "z" and IsKeyDown("CTRL") then
				self.build.spec:Undo()
				self.build.buildFlag = true
				inputEvents[id] = nil
			elseif event.key == "y" and IsKeyDown("CTRL") then
				self.build.spec:Redo()
				self.build.buildFlag = true
				inputEvents[id] = nil
			end
		end
	end
	self:ProcessControlsInput(inputEvents, viewPort)

	local treeViewPort = { x = viewPort.x, y = viewPort.y, width = viewPort.width, height = viewPort.height - 32 }
	self.viewer:Draw(self.build, treeViewPort, inputEvents)

	--[[self.controls.specSelect.sel = self.activeSpec
	wipeTable(self.controls.specSelect.list)
	for id, spec in ipairs(self.specList) do
		t_insert(self.controls.specSelect.list, spec.title or "Default")
	end
	t_insert(self.controls.specSelect.list, "Manage trees...")]]
	if not self.controls.treeSearch.hasFocus then
		self.controls.treeSearch:SetText(self.viewer.searchStr)
	end
	self.controls.treeHeatMap.state = self.viewer.showHeatMap

	SetDrawLayer(1)

	SetDrawColor(0.05, 0.05, 0.05)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - 28, viewPort.width, 28)
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - 32, viewPort.width, 4)

	self:DrawControls(viewPort)
end

function TreeTabClass:Load(xml, dbFileName)
	self.specList = { }
	if xml.elem == "Spec" then
		-- Import single spec from old build
		self.specList[1] = common.New("PassiveSpec", self.build)
		self.specList[1]:Load(xml, dbFileName)
		self.activeSpec = 1
		self.build.spec = self.specList[1]
		return
	end
	for _, node in pairs(xml) do
		if type(node) == "table" then
			if node.elem == "Spec" then
				local newSpec = common.New("PassiveSpec", self.build)
				newSpec:Load(node, dbFileName)
				t_insert(self.specList, newSpec)
			end
		end
	end
	if not self.specList[1] then
		self.specList[1] = common.New("PassiveSpec", self.build)
	end
	self:SetActiveSpec(tonumber(xml.attrib.activeSpec) or 1)
end

function TreeTabClass:Save(xml)
	xml.attrib = { 
		activeSpec = tostring(self.activeSpec)
	}
	for _, spec in ipairs(self.specList) do
		local child = {
			elem = "Spec"
		}
		spec:Save(child)
		t_insert(xml, child)
	end
end

function TreeTabClass:SetActiveSpec(specId)
	self.activeSpec = m_min(specId, #self.specList)
	self.build.spec = self.specList[self.activeSpec]
	self.build.buildFlag = true
end

function TreeTabClass:OpenSpecManagePopup()
	main:OpenPopup(500, 400, "Manage Passive Trees", {
	})
end

function TreeTabClass:OpenImportPopup()
	local treeLink = ""
	local showMsg
	main:OpenPopup(380, 110, "Import Tree", {
		common.New("LabelControl", nil, 0, 20, 0, 16, "Enter passive tree link:"),
		edit = common.New("EditControl", nil, 0, 40, 350, 18, "", nil, nil, nil, function(buf)
			treeLink = buf 
			showMsg = nil
		end),
		common.New("LabelControl", nil, 0, 58, 0, 16, function() return showMsg or "" end),
		import = common.New("ButtonControl", nil, -45, 80, 80, 20, "Import", function()
			if #treeLink > 0 then
				if treeLink:match("poeurl%.com/") then
					local curl = require("lcurl")
					local easy = curl.easy()
					easy:setopt_url(treeLink)
					easy:setopt_writefunction(function(data)
						return true
					end)
					easy:perform()
					local redirect = easy:getinfo(curl.INFO_REDIRECT_URL)
					easy:close()
					if not redirect or redirect == treeLink then
						showMsg = "^1Failed to resolve PoEURL link"
						return
					end
					treeLink = redirect
				end
				local errMsg = self.build.spec:DecodeURL(treeLink)
				if errMsg then
					showMsg = "^1"..errMsg
				else
					self.build.spec:AddUndoState()
					self.build.buildFlag = true
					main:ClosePopup()
				end
			end
		end),
		common.New("ButtonControl", nil, 45, 80, 80, 20, "Cancel", function()
			main:ClosePopup()
		end),
	}, "import", "edit")
end

function TreeTabClass:OpenExportPopup()
	local treeLink = self.build.spec:EncodeURL("https://www.pathofexile.com/passive-skill-tree/")
	local popup
	popup = main:OpenPopup(380, 100, "Export Tree", {
		common.New("LabelControl", nil, 0, 20, 0, 16, "Passive tree link:"),
		edit = common.New("EditControl", nil, 0, 40, 350, 18, treeLink, nil, "%Z"),
		shrink = common.New("ButtonControl", nil, -90, 70, 140, 20, "Shrink with PoEURL", function()
			popup.controls.shrink.enabled = false
			popup.controls.shrink.label = "Shrinking..."
			launch:DownloadPage("http://poeurl.com/shrink.php?url="..treeLink, function(page, errMsg)
				popup.controls.shrink.label = "Done"
				if errMsg or not page:match("%S") then
					main:OpenMessagePopup("PoEURL Shortener", "Failed to get PoEURL link. Try again later.")
				else
					treeLink = "http://poeurl.com/"..page
					popup.controls.edit:SetText(treeLink)
					popup:SelectControl(popup.controls.edit)
				end
			end)
		end),
		common.New("ButtonControl", nil, 30, 70, 80, 20, "Copy", function()
			Copy(treeLink)
		end),
		done = common.New("ButtonControl", nil, 120, 70, 80, 20, "Done", function()
			main:ClosePopup()
		end),
	}, "done", "edit")
end