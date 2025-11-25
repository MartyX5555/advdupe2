local invalidCharacters = { "\"", ":"}
function AdvDupe2.SanitizeFilename(filename)
	for i=1, #invalidCharacters do
		filename = string.gsub(filename, invalidCharacters[i], "_")
	end
	filename = string.gsub(filename, "%s+", " ")

	return filename
end

function AdvDupe2.ReceiveFile(data, autoSave)

	AdvDupe2.RemoveProgressBar()
	if not data then
		AdvDupe2.Notify("File was not saved!",NOTIFY_ERROR,5)
		return
	end
	local path
	if autoSave then
		if(LocalPlayer():GetInfo("advdupe2_auto_save_overwrite")~="0")then
			path = AdvDupe2.GetFilename(AdvDupe2.AutoSavePath, true)
		else
			path = AdvDupe2.GetFilename(AdvDupe2.AutoSavePath)
		end
	else
		path = AdvDupe2.GetFilename(AdvDupe2.SavePath)
	end

	path = AdvDupe2.SanitizeFilename(path)
	local dupefile = file.Open(path, "wb", "DATA")
	if not dupefile then
		AdvDupe2.Notify("File was not saved!",NOTIFY_ERROR,5)
		return
	end
	dupefile:Write(data)
	dupefile:Close()

	local errored = false
	if(LocalPlayer():GetInfo("advdupe2_debug_openfile")=="1")then
		if(not file.Exists(path, "DATA"))then AdvDupe2.Notify("File does not exist", NOTIFY_ERROR) return end

		local readFile = file.Open(path, "rb", "DATA")
		if not readFile then AdvDupe2.Notify("File could not be read", NOTIFY_ERROR) return end
		local readData = readFile:Read(readFile:Size())
		readFile:Close()
		local success,dupe,info,moreinfo = AdvDupe2.Decode(readData)
		if(success)then
			AdvDupe2.Notify("DEBUG CHECK: File successfully opens. No EOF errors.")
		else
			AdvDupe2.Notify("DEBUG CHECK: " .. dupe, NOTIFY_ERROR)
			errored = true
		end
	end

	local filename = string.StripExtension(string.GetFileFromFilename( path ))
	if autoSave then
		if(IsValid(AdvDupe2.FileBrowser.AutoSaveNode))then
			local add = true
			for i=1, #AdvDupe2.FileBrowser.AutoSaveNode.Files do
				if(filename==AdvDupe2.FileBrowser.AutoSaveNode.Files[i].Label:GetText())then
					add=false
					break
				end
			end
			if(add)then
				AdvDupe2.FileBrowser.AutoSaveNode:AddFile(filename)
				AdvDupe2.FileBrowser.Browser.pnlCanvas:Sort(AdvDupe2.FileBrowser.AutoSaveNode)
			end
		end
	else
		AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode:AddFile(filename)
		AdvDupe2.FileBrowser.Browser.pnlCanvas:Sort(AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode)
	end
	if(!errored)then
		AdvDupe2.Notify("File successfully saved!",NOTIFY_GENERIC, 5)
	end
end

express.Receive( "AdvDupe2_ReceiveFile", function(inputdata)
	local autoSave = inputdata.autosave == 1
	AdvDupe2.ReceiveFile(inputdata.data, autoSave)
end)
--[[
net.Receive("AdvDupe2_ReceiveFile", function()
	local autoSave = net.ReadUInt(8) == 1
	net.ReadStream(nil, function(data)
		AdvDupe2.ReceiveFile(data, autoSave)
	end)
end)
]]

concommand.Add( "AdvDupe2_AbortUpload", function( ply, cmd, args )
	if AdvDupe2.Uploading then
		AdvDupe2.Uploading = nil
		AdvDupe2.RemoveProgressBar()
		net.Start("AdvDupe2_CancelUpload")
		net.SendToServer()
	end
end )

function AdvDupe2.SendFile(name, read, dupe, info, moreinfo)

	AdvDupe2.Uploading = true
	AdvDupe2.InitProgressBar("Uploading: ")

	-- Sends a signal to the server a file is about to be sent. It will arrive before the express do.
	net.Start("AdvDupe2_ReceiveFile_Request")
	net.SendToServer()

	express.Send( "AdvDupe2_ReceiveFile", {name = name, read = read}, function()
		AdvDupe2.Uploading = nil
		AdvDupe2.RemoveProgressBar()
		AdvDupe2.LoadGhosts(dupe, info, moreinfo, name)
	end)	
end

function AdvDupe2.UploadFile(ReadPath, ReadArea)
	if AdvDupe2.Uploading then AdvDupe2.Notify("Already opening file, please wait.", NOTIFY_ERROR) return end
	if ReadArea == 0 then
		ReadPath = AdvDupe2.DataFolder .. "/" .. ReadPath .. ".txt"
	elseif ReadArea == 1 then
		ReadPath = AdvDupe2.DataFolder .. "/-Public-/" .. ReadPath .. ".txt"
	else
		ReadPath = "adv_duplicator/" .. ReadPath .. ".txt"
	end

	if not file.Exists(ReadPath, "DATA") then AdvDupe2.Notify("File does not exist", NOTIFY_ERROR) return end

	local read = file.Read(ReadPath)
	if not read then AdvDupe2.Notify("File could not be read", NOTIFY_ERROR) return end
	local name = string.Explode("/", ReadPath)
	name = name[#name]
	name = string.sub(name, 1, #name-4)

	local success, dupe, info, moreinfo = AdvDupe2.Decode(read)
	if success then
		AdvDupe2.RemoveGhosts()
		AdvDupe2.SendFile(name, read, dupe, info, moreinfo)
	else
		AdvDupe2.Notify("File could not be decoded. (" .. dupe .. ") Upload Canceled.", NOTIFY_ERROR)
	end
end

hook.Add("OnLuaError", "AdvDupe2_RemoveProgressBar", function(error, realm, stack, name, addon_id )
	print("EXPRESS BRUTALLY RAPED")
	print(error, realm, stack, name, addon_id )
end)