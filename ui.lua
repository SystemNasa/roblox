local library = {};
local gs = cloneref or function(obj) return obj end;
local get_service = function(service_name)
	return gs(game:GetService(service_name));
end;

library.services = {
	tween_service = get_service("TweenService"),
	user_input_service = get_service("UserInputService"),
	players_service = get_service("Players"),
	gui_service = get_service("GuiService"),
	run_service = get_service("RunService"),
	http_service = get_service("HttpService")
};

library.theme = {
	title = "foambook",
	background_color = Color3.fromRGB(10, 10, 10),
	primary_color = Color3.fromRGB(15, 15, 15),
	secondary_color = Color3.fromRGB(25, 25, 25),
	tertiary_color = Color3.fromRGB(35, 35, 35),
	accent_color = Color3.fromRGB(80, 80, 255),
	text_color = Color3.fromRGB(255, 255, 255),
	muted_text_color = Color3.fromRGB(150, 150, 150),
	stroke_color = Color3.fromRGB(35, 35, 35),
	font = Enum.Font.GothamSemibold,
	corner_radius = UDim.new(0, 8),
	padding = UDim.new(0, 8),
	element_gap = 8,
	animation_speed = 0.25
};

library.api = {};
library.api.__index = library.api;

local create_instance = function(instance_type, properties)
	local object = Instance.new(instance_type);
	for key, value in pairs(properties) do
		object[key] = value;
	end;
	if object:IsA("GuiObject") then
		object.BorderSizePixel = 0;
	end;
	return object;
end;

-- Config system for saving/loading favorites
local config_folder = "FoambookConfigs";
local function get_config_path(window_title)
	return config_folder .. "/" .. window_title .. "_favorites.json";
end;

local function save_favorites(window_title, favorites)
	if not isfolder(config_folder) then
		makefolder(config_folder);
	end;
	
	local favorites_list = {};
	for text, is_fav in pairs(favorites) do
		if is_fav then
			table.insert(favorites_list, text);
		end;
	end;
	
	local success, err = pcall(function()
		writefile(get_config_path(window_title), library.services.http_service:JSONEncode(favorites_list));
	end);
	
	if not success then
		warn("Failed to save favorites:", err);
	end;
end;

local function load_favorites(window_title)
	local config_path = get_config_path(window_title);
	
	if not isfile(config_path) then
		return {};
	end;
	
	local success, result = pcall(function()
		local content = readfile(config_path);
		return library.services.http_service:JSONDecode(content);
	end);
	
	if not success then
		warn("Failed to load favorites:", result);
		return {};
	end;
	
	-- Convert list to dictionary
	local favorites = {};
	for _, text in ipairs(result) do
		favorites[text] = true;
	end;
	
	return favorites;
end;

library.api.new = function(title)
	local window = {};
	setmetatable(window, library.api);
	
	window.title = title or library.theme.title;
	window.buttons = {};
	window.favorite_buttons = {};
	window.favorites = load_favorites(window.title); -- Load saved favorites
	window.search_query = "";
	window.accent_elements = {};
	
	-- Fixed phone dimensions with 133% scale
	local phone_width = 300;
	local phone_height = 300;
	local scale = 1;
	
	local theme = library.theme;
	
	window.screen_gui = create_instance("ScreenGui", {
		Name = "FoambookUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2147483647
	});
	
	local drag_frame = create_instance("Frame", {
		Name = "DragFrame",
		Size = UDim2.fromOffset(phone_width, phone_height),
		Position = UDim2.new(0.5, -phone_width / 2, 0.5, -phone_height / 2),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = window.screen_gui
	});
	
	create_instance("UIScale", {
		Scale = scale,
		Parent = drag_frame
	});
	
	local main_frame = create_instance("Frame", {
		Name = "MainFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.background_color,
		ClipsDescendants = true,
		Parent = drag_frame
	});
	
	create_instance("UICorner", {
		CornerRadius = theme.corner_radius,
		Parent = main_frame
	});
	
	create_instance("UIStroke", {
		Color = theme.stroke_color,
		Thickness = 1,
		Transparency = 0.5,
		Parent = main_frame
	});
	
	-- Title bar
	local title_bar = create_instance("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, -16, 0, 35),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = theme.primary_color,
		Active = true,
		Parent = main_frame
	});
	
	create_instance("UICorner", {
		CornerRadius = theme.corner_radius,
		Parent = title_bar
	});
	
	create_instance("UIStroke", {
		Color = theme.stroke_color,
		Thickness = 1,
		Parent = title_bar
	});
	
	create_instance("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = window.title,
		TextColor3 = theme.text_color,
		Font = theme.font,
		TextSize = 15,
		Parent = title_bar
	});
	
	-- Search bar
	local search_container = create_instance("Frame", {
		Name = "SearchContainer",
		Size = UDim2.new(1, -16, 0, 35),
		Position = UDim2.new(0, 8, 0, 51),
		BackgroundColor3 = theme.secondary_color,
		Parent = main_frame
	});
	
	create_instance("UICorner", {
		CornerRadius = theme.corner_radius,
		Parent = search_container
	});
	
	create_instance("UIStroke", {
		Color = theme.stroke_color,
		Thickness = 1,
		Parent = search_container
	});
	
	create_instance("ImageLabel", {
		Name = "SearchIcon",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(10, 9.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6034509993",
		ImageColor3 = theme.muted_text_color,
		Parent = search_container
	});
	
	local search_box = create_instance("TextBox", {
		Name = "SearchBox",
		Size = UDim2.new(1, -36, 1, 0),
		Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1,
		Font = theme.font,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = theme.muted_text_color,
		TextColor3 = theme.text_color,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = search_container
	});
	
	-- Scrolling content
	local scrolling_frame = create_instance("ScrollingFrame", {
		Name = "Content",
		Size = UDim2.new(1, -16, 1, -102),
		Position = UDim2.fromOffset(8, 94),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarImageColor3 = theme.accent_color,
		ScrollBarThickness = 2,
		Parent = main_frame
	});
	
	table.insert(window.accent_elements, {
		obj = scrolling_frame,
		prop = "ScrollBarImageColor3"
	});
	
	create_instance("UIPadding", {
		PaddingTop = UDim.new(0, 0),
		PaddingBottom = UDim.new(0, 8),
		Parent = scrolling_frame
	});
	
	local list_layout = create_instance("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scrolling_frame
	});
	
	list_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrolling_frame.CanvasSize = UDim2.new(0, 0, 0, list_layout.AbsoluteContentSize.Y + 8);
	end);
	
	-- Drag functionality
	local is_dragging, drag_offset = false, nil;
	
	title_bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			is_dragging = true;
			drag_offset = Vector2.new(input.Position.X, input.Position.Y - library.services.gui_service:GetGuiInset().Y) - drag_frame.AbsolutePosition;
		end;
	end);
	
	library.services.user_input_service.InputChanged:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and is_dragging then
			local viewport = workspace.CurrentCamera.ViewportSize;
			local size = drag_frame.AbsoluteSize;
			local pos = Vector2.new(input.Position.X, input.Position.Y) - drag_offset;
			drag_frame.Position = UDim2.fromOffset(
				math.clamp(pos.X, 0, viewport.X - size.X),
				math.clamp(pos.Y, 0, viewport.Y - size.Y)
			);
		end;
	end);
	
	library.services.user_input_service.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and is_dragging then
			is_dragging = false;
		end;
	end);
	
	-- Filter and sort buttons
	local update_button_visibility = function()
		local regular_list = {};
		local favorite_list = {};
		
		for _, btn_data in pairs(window.buttons) do
			local matches_search = window.search_query == "" or 
				btn_data.text:lower():find(window.search_query:lower(), 1, true);
			
			btn_data.frame.Visible = matches_search;
			
			if matches_search then
				table.insert(regular_list, btn_data);
			end;
		end;
		
		-- Collect favorite buttons
		for text, fav_data in pairs(window.favorite_buttons) do
			local matches_search = window.search_query == "" or 
				text:lower():find(window.search_query:lower(), 1, true);
			fav_data.frame.Visible = matches_search;
			if matches_search then
				table.insert(favorite_list, fav_data);
			end;
		end;
		
		-- Sort alphabetically
		table.sort(regular_list, function(a, b) return a.text < b.text end);
		table.sort(favorite_list, function(a, b) return a.text < b.text end);
		
		-- Assign layout orders (favorites first, then regular)
		local order = 1;
		
		-- First show favorite copies at the TOP
		for _, fav_data in ipairs(favorite_list) do
			fav_data.frame.LayoutOrder = order;
			order = order + 1;
		end;
		
		-- Then show regular buttons below favorites
		for _, btn_data in ipairs(regular_list) do
			btn_data.frame.LayoutOrder = order;
			order = order + 1;
		end;
	end;
	
	search_box:GetPropertyChangedSignal("Text"):Connect(function()
		window.search_query = search_box.Text;
		update_button_visibility();
	end);
	
	window.screen_gui.Parent = library.services.players_service.LocalPlayer.PlayerGui;
	
	-- API
	window.add_button = function(self, text, callback)
		-- Forward declare to allow recursion
		local create_button_ui;
		
		create_button_ui = function(parent, is_favorite_copy)
			local button = create_instance("TextButton", {
				Name = (is_favorite_copy and "FavButton_" or "Button_") .. text,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = theme.secondary_color,
				Text = "",
				AutoButtonColor = false,
				Parent = parent
			});
			
			create_instance("UICorner", {
				CornerRadius = theme.corner_radius,
				Parent = button
			});
			
			create_instance("UIStroke", {
				Color = theme.stroke_color,
				Thickness = 1,
				Parent = button
			});
			
			local label = create_instance("TextLabel", {
				Name = "Label",
				Size = UDim2.new(1, -35, 1, 0),
				Position = UDim2.fromOffset(15, 0),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = theme.text_color,
				Font = theme.font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = button
			});
			
			-- Star button for favoriting
			local star_button = create_instance("ImageButton", {
				Name = "StarButton",
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.new(1, -15, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://6031068420",
				ImageColor3 = theme.muted_text_color,
				Parent = button
			});
			
			-- Update star appearance
			local update_star = function()
				local is_fav = window.favorites[text];
				star_button.ImageColor3 = is_fav and Color3.fromRGB(255, 215, 0) or theme.muted_text_color;
			end;
			
			-- Star button click
			star_button.MouseButton1Click:Connect(function()
				window.favorites[text] = not window.favorites[text];
				
				if window.favorites[text] then
					-- Create favorite copy
					if not window.favorite_buttons[text] then
						local fav_button_frame = create_button_ui(scrolling_frame, true);
						window.favorite_buttons[text] = {
							frame = fav_button_frame,
							text = text
						};
					end;
				else
					-- Remove favorite copy
					if window.favorite_buttons[text] then
						window.favorite_buttons[text].frame:Destroy();
						window.favorite_buttons[text] = nil;
					end;
				end;
				
				-- Update all star buttons for this text
				if window.buttons[text] then
					local main_star = window.buttons[text].frame:FindFirstChild("StarButton");
					if main_star then
						main_star.ImageColor3 = window.favorites[text] and Color3.fromRGB(255, 215, 0) or theme.muted_text_color;
					end;
				end;
				if window.favorite_buttons[text] then
					local fav_star = window.favorite_buttons[text].frame:FindFirstChild("StarButton");
					if fav_star then
						fav_star.ImageColor3 = window.favorites[text] and Color3.fromRGB(255, 215, 0) or theme.muted_text_color;
					end;
				end;
				
				-- Save favorites to file
				save_favorites(window.title, window.favorites);
				
				update_button_visibility();
			end);
			
			update_star();
			
			-- Hover effects
			local anim_info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
			
			button.MouseEnter:Connect(function()
				library.services.tween_service:Create(button, anim_info, {
					BackgroundColor3 = theme.tertiary_color
				}):Play();
			end);
			
			button.MouseLeave:Connect(function()
				library.services.tween_service:Create(button, anim_info, {
					BackgroundColor3 = theme.secondary_color
				}):Play();
			end);
			
			button.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					library.services.tween_service:Create(button, TweenInfo.new(0.1), {
						BackgroundColor3 = theme.primary_color
					}):Play();
				end;
			end);
			
			button.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					library.services.tween_service:Create(button, TweenInfo.new(0.1), {
						BackgroundColor3 = theme.tertiary_color
					}):Play();
				end;
			end);
			
			button.MouseButton1Click:Connect(function()
				if callback then
					callback();
				end;
			end);
			
			return button;
		end;
		
		local button = create_button_ui(scrolling_frame, false);
		
		local btn_data = {
			frame = button,
			text = text
		};
		
		window.buttons[text] = btn_data;
		
		-- If this button was previously favorited, create the favorite copy immediately
		if window.favorites[text] then
			local fav_button_frame = create_button_ui(scrolling_frame, true);
			window.favorite_buttons[text] = {
				frame = fav_button_frame,
				text = text
			};
		end;
		
		update_button_visibility();
		return button;
	end;
	
	window.set_accent = function(self, color)
		theme.accent_color = color;
		for _, data in ipairs(window.accent_elements) do
			if data.obj and data.obj.Parent then
				data.obj[data.prop] = color;
			end;
		end;
	end;
	
	return window;
end;

return library
