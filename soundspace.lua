local librepo = "https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/"
local UILib = loadstring(game:HttpGet(librepo..'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(librepo.."addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(librepo.."addons/SaveManager.lua"))()

-- setup ui
local winMain = UILib:CreateWindow("Sound Space")

-- services
local runS = game:GetService("RunService")
local repF = game:GetService("ReplicatedFirst")
local repS = game:GetService("ReplicatedStorage")
local tweS = game:GetService("TweenService")
local inpS = game:GetService("UserInputService")
local players = game:GetService("Players")

getgenv().wait = task.wait

do

	local player = players.LocalPlayer
	local renv = getrenv()

	local gameScript = getsenv(repF.GameScript)
	local gameScriptR = require(repF.GameScript)
	local music = repF.GameScript:WaitForChild("Music")

	local currentMap = nil

	local playerModule = require(repF.Modules.Data.Player)
	local playerData = playerModule:GetData()

	local permissionsModule = require(repS.Modules.Perms.Permissions)

	local UpdateCubes,UpdateSaber

	-- Hooks
	do
		UpdateCubes = gameScript.UpdateCubes
		UpdateSaber = gameScript.UpdateSaber
		local lastUpdate = tick()
		runS.Heartbeat:Connect(function()
			if tick()-lastUpdate > 10 then
				lastUpdate = tick()
				playerData = playerModule:GetData()
			end
		end)
	end
	
	local modInfo = require(game.ReplicatedStorage.Modules.Util.Mod)
	local cursor = workspace.Client:WaitForChild("Cursor")

	local tab = winMain:AddTab("Sound Space")
	
	local aimbot = tab:AddRightTabbox("Cursor")

	local function getCursor()
		local pos = debug.getupvalue(UpdateSaber,5)
		return Vector2.new(pos.Z,pos.Y)
	end
	local function moveCursor(vec2)
		debug.setupvalue(UpdateSaber,5,Vector3.new(0.05,vec2.Y,vec2.X))
	end

	-- Replays
	do
		local replays = tab:AddLeftGroupbox("Replays")
		replays:AddToggle("Replay",{Text="Replays Enabled",Default=false})
		replays:AddToggle("ReplayNoPause",{Text="Ignore Pauses",Default=false})
		replays:AddDropdown("ReplayMode",{Text="Replay Mode",Default=1,Values={
			"Record",
			"Playback"
		}})
		replays:AddDropdown("ReplaySelect",{Text="Replays",Default=1,Values={
			"None"
		}})
		local replayList = {}
		local currentReplay = {}
		local function readList()
			if not isfile("Sound Space/replays.json") then return end
			replayList = game:GetService("HttpService"):JSONDecode(readfile("Sound Space/replays.json"))
			local names = {}
			for idx,_ in pairs(replayList) do
				table.insert(names,idx)
			end
			Options.ReplaySelect.Values = names
			Options.ReplaySelect:SetValues()
			Options.ReplaySelect:Display()
		end
		local function saveList()
			if not isfolder("Sound Space") then
				makefolder("Sound Space")
			end
			writefile("Sound Space/replays.json",game:GetService("HttpService"):JSONEncode(replayList))
		end
		readList()
		replays:AddInput("ReplayName",{Text="Replay Name",Tooltip="The name of the replay you're saving",Placeholder="Replay Name",Default="Replay #"..#replayList+1})
		replays:AddButton("Save Replay",function()
			local replayName = Options.ReplayName.Value
			replayList[replayName] = currentReplay
			saveList()
			UILib:Notify("Saved replay "..replayName)
			readList()
		end)
		local keypresses = {}
		local function recordFrame(t,o)
			local kps = keypresses
			keypresses = {}
			return {
				t;
				o;
				{workspace.CurrentCamera.CFrame:GetComponents()};
				{getCursor().X,getCursor().Y};
				kps;
			}
		end
		local isReplay = false
		local isRecording = false
		local replayTime = 0
		local replayTimeOffset = 0
		local currentFrame = 1
		local keycodes = {[Enum.KeyCode.Space]=0x20}
		local function processFrame(frame)
			local cameraCFrame = CFrame.new(unpack(frame[3]))
			local cursorPos = Vector2.new(unpack(frame[4]))
			local keys = frame[5]
			workspace.CurrentCamera.CFrame = cameraCFrame
			moveCursor(cursorPos)
			if Toggles.ReplayNoPause.Value then return end
			for _,key in pairs(keys) do
				if key[2] then
					keyrelease(key[1])
				else
					keypress(key[1])
				end
			end
		end
		runS.RenderStepped:Connect(function(delta)
			if renv._G.IsRunning and Toggles.Replay.Value then
				if not isReplay then
					isReplay = true
					isRecording = Options.ReplayMode.Value == "Record"
					currentFrame = 1
					replayTime = 0
					replayTimeOffset = 0
					if isRecording then
						currentReplay = {}
					elseif Options.ReplaySelect.Value ~= "None" then
						currentReplay = replayList[Options.ReplaySelect.Value]
					end
				end
				local musicTime = music.TimePosition - (debug.getupvalue(UpdateCubes,3)+55)/1000
				if (replayTime-replayTimeOffset) == musicTime then
					replayTimeOffset += delta
				end
				replayTime = musicTime + replayTimeOffset
				if isRecording then
					table.insert(currentReplay,recordFrame(replayTime,replayTimeOffset))
				else
					local frame = currentReplay[currentFrame]
					if replayTime > frame[1] then
						repeat
							processFrame(frame)
							currentFrame += 1
							frame = currentReplay[currentFrame] or {0}
						until currentFrame == #currentReplay or replayTime <= frame[1]
					end
				end
			else
				isReplay = false
			end
		end)
		inpS.InputBegan:Connect(function(input,processed)
			if not isReplay or not isRecording then return end
			if processed then return end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if not keycodes[input.KeyCode] then return end
				table.insert(keypresses,{keycodes[input.KeyCode],false})
			end
		end)
		inpS.InputEnded:Connect(function(input,processed)
			if not isReplay or not isRecording then return end
			if processed then return end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if not keycodes[input.KeyCode] then return end
				table.insert(keypresses,{keycodes[input.KeyCode],true})
			end
		end)
	end

	-- Cursor
	do
		local cursorMods = aimbot:AddTab("Cursor")
		cursorMods:AddToggle("CursorTrail",{Text="Cursor Trail",Default=false})
		cursorMods:AddSlider("CursorTrailInterval",{Text="Trail Interval",Default=0.1,Min=0.1,Max=1,Rounding=2})
		cursorMods:AddSlider("CursorTrailDecay",{Text="Trail Decay",Default=0.15,Min=0.01,Max=1,Rounding=2})
		local function createTrail(pos,t)
			t = t or 0
			local trail = cursor:Clone()
			trail.Position = pos
			local trailUI = trail:FindFirstChildOfClass("SurfaceGui") or player.PlayerGui.CursorGui:Clone()
			trailUI.Adornee = trail
			trailUI.Parent = trail
			trail.Parent = workspace
			trail.Size -= Vector3.new(0,0.525,0.525)*t
			trail.Position -= Vector3.new(t*0.1,0,0)
			repeat
				local d = runS.RenderStepped:Wait()/Options.CursorTrailDecay.Value
				t += d
				trail.Size -= Vector3.new(0,0.525,0.525)*d
				trail.Position -= Vector3.new(d*0.1,0,0)
			until t >= 1
			trail:Destroy()
			trailUI:Destroy()
		end
		local trailPos = Vector3.new(0,0,0)
		runS.RenderStepped:Connect(function(delta)
			if Toggles.CursorTrail.Value then
				local posDiff = trailPos - cursor.Position
				local mag = posDiff.Magnitude
				local trailDist = Options.CursorTrailInterval.Value
				if mag >= trailDist then
					local oldTrailPos = trailPos
					trailPos = cursor.Position
					local intervals = math.floor(mag/trailDist)
					for i = 1,intervals do
						local t = i/intervals
						local pos = cursor.Position:Lerp(oldTrailPos,math.clamp(t,0,1))
						coroutine.wrap(createTrail)(pos,t*(delta/Options.CursorTrailDecay.Value))
					end
				end
			end
		end)
	end
	-- Cursor Dance
	do
		local dancer = aimbot:AddTab("Dance")
		dancer:AddToggle("Dance",{Text="Cursor Dance",Default=false})
		dancer:AddToggle("DanceBounces",{Text="Bounce",Default=true})
		dancer:AddDropdown("DanceMode", {Text="Mode",Default=2,Values={
			"Linear",
			"Half-Circle",
			"Circle"
		}})
		dancer:AddSlider("DanceRadius",{Text="Radius Multiplier",Default=1,Min=0.1,Max=2,Rounding=1})
		dancer:AddSlider("DanceCrosses",{Text="Crossovers",Default=0,Min=0,Max=5,Rounding=0})
		dancer:AddDropdown("DanceDir", {Text="Direction",Default=1,Values={
			"CW",
			"CCW",
			"Alternate"
		}})
		local lastStop
		local altDirection = false
		local function bounceCheck(position)
		    local clamp = 3 - (0.525 / 2)
			position = Vector2.new(position.X,position.Y-3)
    		while math.abs(position.X) > clamp or math.abs(position.Y) > clamp do
    			if position.X > clamp then
    				position = Vector2.new(clamp - (position.X - clamp),position.Y)
    			elseif position.X < -clamp then
    				position = Vector2.new(-clamp + (-position.X - clamp),position.Y)
    			end
    			if position.Y > clamp then
    				position = Vector2.new(position.X,clamp - (position.Y - clamp))
    			elseif position.Y < -clamp then
    				position = Vector2.new(position.X,-clamp + (-position.Y - clamp))
    			end
    		end
			position = Vector2.new(position.X,position.Y+3)
    		return position
		end
		local function ellipse(startPos,stopPos,diff,crosses,radius)
			local direction = Options.DanceDir.Value == "CW" or (Options.DanceDir.Value == "Alternate" and altDirection)
			local look = stopPos - startPos
			local mid = (startPos + stopPos) / 2
			local up = (Vector2.new(-look.Y, look.X) / 2) * radius
			if direction then
				up = -up
			end
			local p = mid + look * -math.cos(diff * math.pi) / 2
			if crosses > 0 then
				p += up * math.sin(diff * math.pi * crosses) / crosses
			end
			return p
		end
		local function halfcircle(startPos,stopPos,diff,crosses)
			return ellipse(startPos,stopPos,diff,crosses,Options.DanceRadius.Value)
		end
		local function circle(startPos,stopPos,diff)
			return halfcircle(startPos,stopPos,diff*3*(Options.DanceCrosses.Value+1),1)
		end
		local trailDelay = 0
		runS.RenderStepped:Connect(function(delta)
			if Toggles.Dance.Value and renv._G.IsRunning then
				currentMap = debug.getupvalue(UpdateCubes,9)
				local visibleMap = debug.getupvalue(UpdateCubes,17)
				local time = music.TimePosition - (debug.getupvalue(UpdateCubes,3)+55)/1000
				local start = {Z=1,Y=1,Time=-1000}
				local stop
				local startIdx,stopIdx = 1,1
				local visibleStop,distance
				for cube,data in pairs(visibleMap) do
					if visibleStop == nil or cube.Position.X > distance then
						visibleStop = data.MapCube
						distance = cube.Position.X
					end
				end
				for index,beat in pairs(currentMap) do
					if not visibleStop then
						if beat.Time > time and (stop == nil or (beat.Time < stop.Time)) then
							stop = beat
							stopIdx = index
							start = currentMap[index-1] or start
							startIdx = index-1
						end
					elseif visibleStop == beat then
						start = currentMap[index-1] or start
						startIdx = index-1
						stop = visibleStop
						stopIdx = index
					end
				end
				if stop ~= lastStop then
					altDirection = not altDirection
				end
				lastStop = stop
				local startT = start.Time
				local diff = math.clamp((time-startT)/(stop.Time-startT),0,1)
				local startPos = Vector2.new(start.Z,start.Y)*0.95
				local stopPos = Vector2.new(stop.Z,stop.Y)*0.95
				local pos = stopPos
				if start and stop then
					if Options.DanceMode.Value == "Linear" then -- linear dance
						pos = startPos:Lerp(stopPos,diff)
					elseif Options.DanceMode.Value == "Circle" then -- full circle dance
						pos = circle(startPos,stopPos,diff)
					elseif Options.DanceMode.Value == "Half-Circle" then -- half circle dance
						pos = halfcircle(startPos,stopPos,diff,Options.DanceCrosses.Value+1)
					end
				end
				pos = Vector2.new(pos.X*2-2,pos.Y*2+1)
				if Toggles.DanceBounces.Value then
					pos = bounceCheck(pos)
				end
				moveCursor(pos)
				cursor.CFrame = CFrame.new(0.05,pos.Y,pos.X)
			end
		end)
	end

	-- Hitboxes
	do
		local hitboxes = tab:AddLeftGroupbox("Hitboxes")
		hitboxes:AddToggle("Hitboxes",{Text="Modify Hitboxes",Default=false})
		hitboxes:AddSlider("Extension",{Text="Silent Aim",Default=0,Min=0,Max=6,Rounding=1,Suffix=" studs"})
		hitboxes:AddSlider("HitWindow",{Text="Hit Window",Default=55,Min=55,Max=1000,Rounding=0,Suffix="ms"})
		hitboxes:AddSlider("Offset",{Text="Offset",Default=0,Min=-1,Max=1,Rounding=2,Suffix="s"})
		local function newreg(beat,offset)
			local hitbox = 1.1375
			local hitWindow = 0.055
			local windowOffset = 0
			if Toggles.Hitboxes.Value then
				hitbox += Options.Extension.Value
				hitWindow = Options.HitWindow.Value/1000
				windowOffset = Options.Offset.Value
			end
			local approachRate = playerData.Settings.ApproachRate
			if playerData.Settings.ConstantAR then
				approachRate = approachRate / modInfo.GetModSpeedMult(player.MapData.Mods)
			end
			local beatT = (beat.CFrame.X + 0.875) / approachRate
			beatT += windowOffset
			if beatT < 0 then
				return 0
			end
			if hitWindow + (offset / approachRate) < beatT then
				return 2
			end
			local touching = math.abs(beat.CFrame.Y - cursor.Position.Y) <= hitbox and math.abs(beat.CFrame.Z - cursor.Position.Z) <= hitbox
			if touching then
				return 1
			end
			return 0
		end
		local oldreg = debug.getupvalue(UpdateCubes,18)
		debug.setupvalue(UpdateCubes,18,function(...)
			local s,r = pcall(newreg,...)
			if not s then
				warn(r)
				return oldreg(...)
			end
			return r
		end)
	end

	local misc = tab:AddLeftGroupbox("Misc")
	do -- Set Pauses
		misc:AddInput("Pauses",{Text="Pauses",Default="0",Numeric=true,Placeholder="No. of pauses",Tooltip="No. of pauses"})
		misc:AddButton("Set Pauses",function()
			debug.setupvalue(gameScriptR.PauseGame,9,tonumber(Options.Pauses.Value))
		end)
	end
	do -- Show Staff
		misc:AddToggle("ShowStaff",{Text="Show Online Staff",Default=true})
		local staffGui = Instance.new("ScreenGui")
		syn.protect_gui(staffGui)
		staffGui.Parent = game:GetService("CoreGui")
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1,-32,1,0)
		label.Position = UDim2.new(0,32,0,0)
		label.BackgroundTransparency = 1
		label.TextSize = 36
		label.Font = Enum.Font.Code
		label.TextColor3 = Color3.new(1,1,1)
		label.TextStrokeColor3 = Color3.new(0,0,0)
		label.TextStrokeTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		label.Visible = false
		label.Parent = staffGui
		Toggles.ShowStaff:OnChanged(function()
			if Toggles.ShowStaff.Value then label.Parent = staffGui else label.Parent = nil end
		end)
		local onlineStaff = {}
		local function display()
			label.Visible = #onlineStaff > 0
			label.Text = "Online staff: "..table.concat(onlineStaff,", ")
		end
		local function indexOf(name)
			for i,v in pairs(onlineStaff) do
				if v == name then
					return i
				end
			end
			return false
		end
		local function checkStaff(player,noOutput)
			if permissionsModule:IsMapper(player.UserId) or permissionsModule:IsMod(player.UserId) or permissionsModule:IsAdmin(player.UserId) or permissionsModule:IsOwner(player.UserId) then
				if not indexOf(player.Name) then
					table.insert(onlineStaff,player.Name)
					if not noOutput then
						UILib:Notify("Staff "..player.Name.." has joined the server.")
						UILib:Notify("Online staff: "..table.concat(onlineStaff,", "))
					end
					display()
				end
			end
		end
		for _,v in pairs(players:GetPlayers()) do
			checkStaff(v,true)
		end
		if #onlineStaff > 0 then
			UILib:Notify("Online staff: "..table.concat(onlineStaff,", "))
		else
			UILib:Notify("No staff are in this server")
		end
		players.PlayerAdded:Connect(checkStaff)
		players.PlayerRemoving:Connect(function(player)
			local index = indexOf(player.Name)
			if index then
				table.remove(onlineStaff,index)
				UILib:Notify("Staff "..player.Name.." has left the server.")
				UILib:Notify("Online staff: "..table.concat(onlineStaff,", "))
				display()
			end
		end)
	end

end

-- settings
local settings = winMain:AddTab("Settings")
local misc = settings:AddLeftGroupbox("Misc.")
misc:AddButton("Rejoin",function() game:GetService("TeleportService"):Teleport(game.PlaceId,game.Players.LocalPlayer) end)
local theme = settings:AddLeftGroupbox("Theme")

-- managers
ThemeManager:SetLibrary(UILib)
SaveManager:SetLibrary(UILib)

SaveManager:IgnoreThemeSettings() 

ThemeManager:SetFolder("Sound Space")
SaveManager:SetFolder("Sound Space")

SaveManager:BuildConfigSection(settings) 
ThemeManager:ApplyToGroupbox(theme)
