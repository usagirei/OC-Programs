local SrcPath, DstPath, PackageFile, Options = ...

local fs = require('filesystem')
local ser = require('serialization')
local computer = require('computer')

if SrcPath == nil then
	SrcPath = fs.canonical(fs.path(os.getenv('_')))
end
if DstPath == nil then
	DstPath = '/usr'
end
if PackageFile == nil then
	PackageFile = fs.concat(SrcPath, 'setup.cfg')
end
if Options == nil then
	Options = {
		label = "",
		reboot = false,
	}
end

local Class = require("libapp.class")
local Application = require("libapp.gui.application")
local Super = require("libapp.gui.window")

local MainLayout = require("libapp.gui.widget.container.layout.mainlayout")
local GridLayout = require("libapp.gui.widget.container.layout.gridlayout")
local StackLayout = require("libapp.gui.widget.container.layout.stacklayout")
local TextView = require("libapp.gui.widget.textview")
local Button = require("libapp.gui.widget.button")
local CheckBox = require("libapp.gui.widget.checkbox")
local ProgressBar = require("libapp.gui.widget.progressbar")
local InputBox = require("libapp.gui.widget.inputbox")

local Text = require("libapp.util.text")

local BS = require("libapp.style.border")
local DS = require("libapp.style.decorator")
local AL = require("libapp.enum.alignment")
local D2 = require("libapp.enum.direction2")
local SM = require("libapp.enum.sizemode")
local LM = require("libapp.enum.labelmode")

---@class FileInfo
---@field srcPath string
---@field dstPath string
---@field fileSize integer
---@field optional boolean

---@alias SetupPackage table<string, SetupComponent>

---@class SetupComponent
---@field order integer
---@field name string
---@field description string
---@field authors string
---@field dependencies string[]
---@field hidden boolean
---@field default boolean
---@field files table<string,string>
---@field paths FileInfo[]
---@field size integer

---@class SetupWizard : Window
local SetupWizard = Class.NewClass(Super, "Wizard")

local BordUL = {
	"│", "│", "─", "",
	"╭", "┬", "", ""
}
local BordBL = {
	"│", "│", "─", "─",
	"├", "┤", "╰", "┴"
}
local BordUR = {
	"", "│", "─", "",
	"", "╮", "", ""
}
local BordBR = {
	"", "│", "─", "─",
	"", "│", "", "╯"
}

---@param package string
function SetupWizard.new(package)
	return Class.NewObj(SetupWizard, package)
end

---@param package string
function SetupWizard:init(package)
	Super.init(self)
	local packs = SetupWizard.LoadPackage(package)
	local arr = {}
	for k, _ in pairs(packs) do arr[#arr + 1] = k end
	table.sort(arr, function(a, b) return packs[a].order < packs[b].order end)

	self.m_Packages = packs
	self.m_PackageOrder = arr
	self.m_PackToggles = {}
	self.m_Busy = false
	self.m_MessageLog = {}
end

function SetupWizard:appendMessage(msg)
	self.m_MessageLog[#self.m_MessageLog + 1] = msg
	self.m_TxtMessage:setValue(self.m_MessageLog)
	self.m_TxtMessage:scrollToBottom()
end

function SetupWizard:createCheckBoxValueCallback(packKey)
	return function(isChecked)
		local v = self.m_Packages[packKey]
		if isChecked then
			for _, depKey in pairs(v.dependencies) do
				self.m_PackToggles[depKey]:setValue(true)
			end
		else
			for pack, tog in pairs(self.m_PackToggles) do
				for _, depKey in pairs(self.m_Packages[pack].dependencies) do
					if depKey == packKey then tog:setValue(false) end
				end
			end
		end
		local s = 0
		for k, t in pairs(self.m_PackToggles) do
			if t:value() then
				s = s + self.m_Packages[k].size
			end
		end

		self.m_ComponentDetails:setLabel(string.format("Size: %d%s", SetupWizard.ByteSize(s)))
	end
end

function SetupWizard:createCheckBoxClickCallback(packKey)
	return function(btn, times)
		if times == 1 then
			local pack = self.m_Packages[packKey]
			local fmt = string.format("%s - §6%s§r\n%s", pack.name, pack.authors, pack.description)
			self.m_ComponentDetails:setValue(fmt)
		elseif times == 2 then
			local me = self.m_PackToggles[packKey]
			me:setValue(not me:value())
		end
	end
end

---@param app Application
---@param w integer
---@param h integer
function SetupWizard:inflate(app, w, h)
	self.m_Application = app

	local lytMain = MainLayout.new(w, h)
	lytMain:setLabel(string.format("%s Setup", Options.label))
	lytMain:setLabelAlignment(AL.Center, AL.Near)
	lytMain:setBorderStyle(BS.Thin_DoubleTop, DS.Double)

	local grdMain = GridLayout.new(0, 0)
	grdMain:setRows(-2, 2, 1, -3)
	grdMain:setColumns(-25, 1, -23)
	lytMain:addChild(grdMain)

	local stkPacks = StackLayout.new(0, 0)
	stkPacks:setLabel("Components")
	stkPacks:setBorderStyle(BordUL, DS.None)
	stkPacks:setDirection(D2.Vertical)
	stkPacks:setSizeMode(SM.Stretch, SM.Stretch)
	grdMain:addChild(stkPacks, 0, 0, 1, 2)

	local txtDetails = TextView.new(0, 0)
	txtDetails:setWordWrap(true)
	txtDetails:setBorderStyle(BordBL, DS.Cap)
	txtDetails:setLabelAlignment(AL.Far, AL.Near)
	grdMain:addChild(txtDetails, 0, 2)
	self.m_ComponentDetails = txtDetails

	local txtMessage = TextView.new(0, 0)
	txtMessage:setWordWrap(false)
	txtMessage:setBorderStyle(BordBR, DS.None)
	grdMain:addChild(txtMessage, 1, 1, 2, 2)
	self.m_TxtMessage = txtMessage

	local tbInstall = InputBox.new(0, 0)
	tbInstall:setLabelMode(LM.Prefix)
	tbInstall:setPopupBorderStyle(BS.Popup_Solid, 10)
	tbInstall:setLabel("Install To:")
	tbInstall:setAutoCompleteCallback(SetupWizard.PathAutoComplete)
	tbInstall:setValueValidationCallback(SetupWizard.PathIsWriteable)
	tbInstall:setValueChangedCallback(function(v) DstPath = v end)
	tbInstall:setValue(DstPath)
	tbInstall:setBorderStyle(BordUR, DS.None)
	grdMain:addChild(tbInstall, 1, 0, 2, 1)

	---@type table<string,CheckBox>
	local packToggles = {}

	self:createCheckBoxClickCallback(self.m_PackageOrder[1])(0, 1)
	for i, k in pairs(self.m_PackageOrder) do
		local v = self.m_Packages[k]
		local pTog = CheckBox.new(0, 1)
		local lab = string.format("%s (%d%s)", v.name, SetupWizard.ByteSize(v.size))
		pTog:setLabel(lab)
		packToggles[k] = pTog
		stkPacks:addChild(pTog)
	end
	self.m_PackToggles = packToggles
	for k, v in pairs(packToggles) do
		v:setValueChangedCallback(self:createCheckBoxValueCallback(k))
		v:setClickCallback(self:createCheckBoxClickCallback(k))
		v:setValue(self.m_Packages[k].default)
	end

	local stkBtns = StackLayout.new(0, 0)
	stkBtns:setSpacing(1)
	stkBtns:setDirection(D2.Horizontal)
	stkBtns:setSizeMode(SM.Automatic, SM.Automatic)
	grdMain:addChild(stkBtns, 2, 3)

	local progFiles = ProgressBar.new(0, 0)
	progFiles:setBorderStyle(BS.SolidShadow, DS.SolidShadow)
	progFiles:setLabelAlignment(AL.Far, AL.Far)
	progFiles:setLabel("Waiting")
	self.m_Progress = progFiles
	grdMain:addChild(progFiles, 0, 3, 2, 1)

	local btnCancel = Button.new(10, 3)
	btnCancel:setLabel("Cancel")
	stkBtns:addChild(btnCancel)

	local btnInstall = Button.new(10, 3)
	btnInstall:setLabel("Install")
	stkBtns:addChild(btnInstall)

	local btnClose = Button.new(20, 3)
	if Options.reboot then
		btnClose:setLabel("Reboot")
		btnClose:setClickCallback(function()
			computer.shutdown(true)
		end)
	else
		btnClose:setLabel("Close")
		btnClose:setClickCallback(function()
			app:exit(1)
		end)
	end
	btnClose:setVisible(false)
	stkBtns:addChild(btnClose)

	btnCancel:setClickCallback(function()
		app:exit(1)
	end)
	btnInstall:setClickCallback(function()
		self.m_Busy = true
		stkPacks:setInteractive(false)
		stkBtns:setInteractive(false)
		tbInstall:setInteractive(false)
		progFiles:setLabel("Installing")
		btnInstall:setVisible(false)
		btnCancel:setVisible(false)

		local function done()
			self.m_Busy = false
			stkBtns:setInteractive(true)
			progFiles:setLabel("Done")
			btnClose:setVisible(true)
		end

		app:startCoroutine(self:Install(), done, done)
	end)

	return lytMain
end

function SetupWizard:onClosing()
	return not self.m_Busy
end

function SetupWizard:Install()
	local co = function()
		---@type FileInfo[]
		local files = {}
		for name, tog in pairs(self.m_PackToggles) do
			local pack = self.m_Packages[name]
			if tog:value() then
				for i, f in ipairs(pack.paths) do
					files[#files + 1] = f
				end
			end
		end
		self.m_Progress:setRange(1, #files)
		local n = 0
		for i, f in ipairs(files) do
			local srcFile = fs.concat(SrcPath, f.srcPath)

			local fileName = fs.name(f.srcPath)
			local dstDir
			if f.dstPath:sub(1, 2) == '//' then
				dstDir = f.dstPath:sub(2)
			else
				dstDir = fs.concat(DstPath, f.dstPath)
			end
			local dstFile = fs.concat(dstDir, fileName)
			fs.makeDirectory(dstDir)
			if (not f.optional) or (not fs.exists(dstFile)) then
				local ok, msg = fs.copy(srcFile, dstFile)
				if not ok then
					self:appendMessage(Text.colorize(msg, Text.Color.Red))
					error(msg)
				end

				local cw = self.m_TxtMessage:contentRect():width()-5
				if #dstFile > cw then
					local of = #dstFile - cw
					local seg = fs.segments(dstFile)
					local s, k = 0, 0
					for j = 1, #seg do
						k = j+1
						s = s + #seg[j] + 1
						if s > of then break end
					end
					dstFile = table.concat({ '..', table.unpack(seg, k) }, '/')
				end
				self:appendMessage(dstFile)
			end
			self.m_Progress:setValue(i)

			n = n + 1
			if n == 5 then
				n = 0
				coroutine.yield()
			end
		end
		self:appendMessage(Text.colorize("Done", Text.Color.Green))
	end
	return co
end

---@param path string
---@param relativeTo string
function SetupWizard.MakeRelative(path, relativeTo)
	local pSeg = fs.segments(path)
	local rSeg = fs.segments(relativeTo)

	local rP = {}
	local flag = false
	for i = 1, #pSeg do
		if (flag == false) and (pSeg[i] ~= rSeg[i]) then
			flag = true
		end
		if flag then
			rP[#rP + 1] = pSeg[i]
		end
	end

	local rel = fs.concat(table.unpack(rP))
	return rel
end

---@param path string
---@param relativeTo string
---@param type? "dir"|"file"
---@return {name:string,path:string,type:"dir"|"file"}[]
function SetupWizard.ListFiles(path, relativeTo, type)
	local rv = {}

	local localPath = fs.concat(relativeTo, path)
	for fName in fs.list(localPath) do
		local absPath = fs.concat(localPath, fName)
		local isDir = fs.isDirectory(absPath)
		local fType = isDir and "dir" or "file"
		if (not type) or (type == fType) then
			local ent = {
				name = fName:gsub("/*$", ""),
				path = SetupWizard.MakeRelative(absPath, relativeTo),
				type = fType,
			}
			rv[#rv + 1] = ent
		end
	end

	return rv
end

---@param inFiles table<string,string>
---@param srcPath string
---@param dstPath string
---@param origin string
function SetupWizard.ExpandFiles(inFiles, srcPath, dstPath, origin)
	local outFiles = {}
	for _, f in pairs(inFiles) do
		if f["type"] == "file" then
			local fPath = f['path']
			outFiles[fPath] = dstPath
		elseif f["type"] == "dir" then
			local srcPathSub = fs.concat(srcPath, f["name"])
			local dstPathSub = fs.concat(dstPath, f["name"])

			local files = SetupWizard.ListFiles(srcPathSub, origin)
			local newFiles = SetupWizard.ExpandFiles(
				files,
				srcPathSub,
				dstPathSub,
				origin
			)

			for fPath, fInfo in pairs(newFiles) do
				outFiles[fPath] = fInfo
			end
		end
	end
	return outFiles
end

---@param info table
---@param root string
---@return FileInfo[]
---@return integer
function SetupWizard.ExpandPackageFiles(info, root)
	local inFiles = info.files
	local outFiles = {}
	---@type boolean
	for fromPath, toPath in pairs(inFiles) do
		if string.find(fromPath, "^:") then
			local relPath = string.gsub(fromPath, "^:(.+)$", "%1"):gsub("/*$", ""):gsub("^/*", "")
			local isAbsolute = toPath:find("^//")

			local files = SetupWizard.ListFiles(relPath, root)
			local newFiles = SetupWizard.ExpandFiles(
				files,
				relPath,
				toPath:gsub("^//", "/"),
				root
			)

			for p, q in pairs(newFiles) do
				if isAbsolute then
					outFiles[p] = "/" .. q
				else
					outFiles[p] = q
				end
			end
		else
			outFiles[fromPath] = toPath
		end
	end

	local iFiles = {}
	local totalSize = 0
	local i = 1
	for fromPath, toPath in pairs(outFiles) do
		local isOpt = string.find(fromPath, "^%?") and true or false
		if isOpt then
			fromPath = string.sub(fromPath, 2)
		end
		local canonical = fs.canonical(fs.concat(root, fromPath))
		local size = fs.size(canonical)
		---@type FileInfo
		iFiles[i] = {
			optional = isOpt,
			srcPath = fromPath,
			dstPath = toPath,
			size = size,
		}
		i = i + 1
		totalSize = totalSize + size
	end

	local function pathSort(a, b)
		local fA = fs.segments(a.srcPath)
		local fB = fs.segments(b.srcPath)

		if #fA ~= #fB then
			return #fA < #fB
		end

		local n = math.max(#fA, #fB)

		for i = 1, n do
			local sA = fA[i]
			local sB = fB[i]

			if sA == nil then
				return true
			elseif sB == nil then
				return false
			elseif sA ~= sB then
				return sA < sB
			end
		end
	end

	table.sort(iFiles, pathSort)

	return iFiles, totalSize
end

---@param source string
function SetupWizard.LoadPackage(source)
	source = fs.canonical(source)
	local origin = fs.path(source)
	local f = io.open(source)
	if f then
		local fData = f:read("a")
		f:close()

		---@type SetupPackage
		local packages = ser.unserialize(fData)
		for _, pInfo in pairs(packages) do
			pInfo.paths, pInfo.size = SetupWizard.ExpandPackageFiles(pInfo, origin)
		end

		return packages
	end

	error('invalid package', 2)
end

---@param size integer
---@return integer size
---@return string unit
function SetupWizard.ByteSize(size)
	local units = { "b", "Kb", "Mb", "Gb", "Tb" }
	local i = 1
	while size > 1024 do
		size = size // 1024
		i = i + 1
	end
	return size, units[i]
end

---@param path string
function SetupWizard.PathIsWriteable(path)
	if not path:find("^/") then return false end
	local node = fs.get(path)
	return not node.isReadOnly()
end

---@param text string
function SetupWizard.PathAutoComplete(text, num)
	local base = text:match("^(/.*/).-$") or '/'
	local rv = {}
	--if not prefixed then
	local dirs = SetupWizard.ListFiles(base, "/", "dir")
	for i, j in pairs(dirs) do
		rv[#rv + 1] = '/' .. j.path .. '/'
	end
	return InputBox.FilterList(rv, text, num)
	--else

	--end
end

local app = Application.new(1, 0)
local wnd = SetupWizard.new(PackageFile)
app:run(wnd)
