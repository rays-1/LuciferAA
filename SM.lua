local httpService = game:GetService("HttpService")


local function printTable(tbl, indent)
    -- Default indentation level
    indent = indent or 0

    -- Iterate through the table
    for key, value in pairs(tbl) do
        -- Create indentation string
        local indentation = string.rep("  ", indent)

        -- Handle different types of values
        if type(value) == "table" then
            -- If the value is a table, print the key and recurse
            print(indentation .. tostring(key) .. ": {")
            printTable(value, indent + 1)
            print(indentation .. "}")
        else
            -- Print the key-value pair
            print(indentation .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = "Toggle", idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = "Slider", idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = "Input", idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name,folder)
		-- Use the provided name or fallback to "PlayerName_LuciferAA"
		local fileName = name.."_LuciferAA" or "PlayerName_LuciferAA"
		self.Folder = folder
		local fullPath = self.Folder .. "/" .. fileName .. ".json"
		local data = {
			objects = {}
		}
	
		-- Save all options from Fluent.Options
		for idx, option in pairs(Fluent.Options) do
			if self.Parser[option.Type] then
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
			end
		end
	
		-- Encode and write to file
		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			warn("Failed to encode data:", encoded)
			return false, "Encoding error"
		end
		print("Saved: "..fullPath)
		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name,folder)
		-- Use the provided name or fallback to "PlayerName_LuciferAA"
		local fileName = name.."_LuciferAA" or "PlayerName_LuciferAA"
		self.Folder = folder
		local filePath = self.Folder .. "/" .. fileName .. ".json"
	
		-- Check if the file exists
		if not isfile(filePath) then
			warn("Config file does not exist:", filePath)
			return false, "File not found"
		end
	
		-- Read and decode the file
		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(filePath))
		if not success then
			warn("Failed to decode config file:", decoded)
			return false, "Decoding error"
		end

		-- Apply loaded data to Fluent.Options
		for _, option in next, decoded.objects do
			if self.Parser[option.type] and not self.Ignore[option.idx] then
				task.spawn(function()
					self.Parser[option.type].Load(option.idx, option)
					-- print("Loading: ",option.idx)
					-- printTable(option)
				end)
			end
		end
		print("Loaded: "..filePath)
		print("Config loaded successfully!")
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. "/settings"
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. "/settings")

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local name = file:sub(pos + 1, start - 1)
					if name ~= "options" then
						table.insert(out, name)
					end
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
        self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = readfile(self.Folder .. "/settings/autoload.txt")

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load autoload config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Auto loaded config %q", name),
				Duration = 7
			})
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		local section = tab:AddSection("Configuration")

		section:AddInput("SaveManager_ConfigName",    { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

		section:AddButton({
            Title = "Create config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigName.Value

                if name:gsub(" ", "") == "" then 
                    return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Invalid config name (empty)",
						Duration = 7
					})
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to save config: " .. err,
						Duration = 7
					})
                end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Created config %q", name),
					Duration = 7
				})

                SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
            end
        })

        section:AddButton({Title = "Load config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Loaded config %q", name),
				Duration = 7
			})
		end})

		section:AddButton({Title = "Overwrite config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to overwrite config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Overwrote config %q", name),
				Duration = 7
			})
		end})

		section:AddButton({Title = "Refresh list", Callback = function()
			SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
		end})

		local AutoloadButton
		AutoloadButton = section:AddButton({Title = "Set as autoload", Description = "Current autoload config: none", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. "/settings/autoload.txt", name)
			AutoloadButton:SetDesc("Current autoload config: " .. name)
			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Set %q to auto load", name),
				Duration = 7
			})
		end})

		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = readfile(self.Folder .. "/settings/autoload.txt")
			AutoloadButton:SetDesc("Current autoload config: " .. name)
		end

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager