-- Mega Man ZX adjustments v3.1.0 by Meta_X --
-- For Mega Man ZX (JP or EN) on BizHawk, DeSmuME, and DraStic --
--List of changes (disable individual ones by commenting out the function call in the main loop at the very bottom):
--Instantly switch models by pressing Select + another key (L: X, R: ZX, Up: HX, Down: FX, Left: LX, Right: PX, A: OX)
--All: Give 1 Weapon Energy to all models every 3 seconds, and refill WE completely at transervers or upon death
--X:  Can perform a small double jump
--    Can switch elements with overdrive button, VERY EXPERIMENTAL!! Do not recommend (off by default)
--ZX: Can perform a small double jump
--HX: Can airdash continuously and repeatedly while overdrive is active and move perpendicularly
--FX: Can perform a recoil-rod style superjump by pressing Jump while using Ground Breaker
--    Can also perform a double jump by holding down while releasing a charge fireball in the air
--    Ground Breaker now multihits vs bosses and can be performed from a lv1 charge
--LX: Can now perform a skullcrush like Model ZX by holding down during jumpslash [planned: deals extra damage]
--    Ice dragon can be performed from a lv1 charge and refunds 2 energy points
--    Ice sled now instantly accelerates to full speed when hit
--    Swimming no longer has a significant deceleration period at the end
--    Swimdashing is now constant speed (instead of decelerating)
--    Infinite swimdashing while in overdrive (or optionally without overdrive)
--    LX can spinslash in the air like model ZX [experimental]
--PX: Can spend 1 WE to perform a MMX6 Shadow Armor-style highjump by pressing Up and Jump
--    Can throw kunai straight forward using subweapon button (use main weapon for the usual kunai spread)
--    Can double jump off of a thrown shuriken
--OX: Can perform a small double jump (or full double jump if overdrive is active)
--    [planned: Skullcrush buffed to do extra damage like it's supposed to]
--    [planned: Giga attacks buffed to have iframes?]
--Dash trail continuously cycles through different colors
--
--Known issues:
--Very risky to reset game or load another save with script running. Disable it before switching then run it again while playing the new file
--Models you haven't yet switched to with the script active can appear on the pause menu with their weapon energy filling past their cap
--Currently assumes Attack Mode Type A (because wtf are you doing otherwise)
--Double jump (and the other custom jump abilities) can have some strange behavior around ceilings and platforms
--  Cannot drop through a platform then double jump and land on that same platform
--Walljumping while not sliding uses up your doublejump
--You must use a different attack before being able to FX superjump again (eg. plain bullet), and it has trouble working on certain terrain
--Ice dragon early charge doesn't always work, such as when released during a cutscene
--X Element switch only works against bosses and is constantly activating and doesnt transfer properly and... just don't use it cept to mess around lol
--
--Changelog:
--v3.1.0
--  Added hitbox viewer; enable ingame by pressing Select + B
--  Fixed bug with FX fireball jump where a bullet fired after double jumping might travel downward
--  Added rectangle drawing support for Bizhawk and Desmume (Bizhawk is preferred)
--  Minor refactoring of a few addresses
--v3.0.0
--  refactored to support bizhawk, desmume, and drastic with a single file
--  changed function arguments format to be more clear
--  added model_switch function for instant switching without loading another cheat
--  converted lx_infinite_swimdash to lx_improved_swimdash
--    you can now swimdash at constant speed, instead of decelerating the whole time
--  fixed minor bug with lx_remove_minimum_swim_distance being directionally inconsistent
--  re-added an old experimental aerial spinslash ability for LX
--  improved velocity writing behavior
--  improved FX doublejump input detection
--    fixed some glitchy behavior + removed ability to doublejump without a fireball
--  improved PX shuriken jump
--    prevent multiple jumps during a single airtime or shuriken
--    added jumping animation
--  added jumping animation for x/zx/ox doublejumps
--  fixed rainbow dash trail affecting pause menu sprites
--??? (long WIP hiatus)
--v2.3.1
--  updated description to account for support for custom control settings


------------------------------- API HANDLER LAYER -------------------------------

local emu_name = ""
if memory and memory.read_u8 then
	emu_name = "bizhawk"
elseif memory and memory.readbyte then
	emu_name = "desmume"
elseif drastic and drastic.get_ds_memory_arm9_8 then
	emu_name = "drastic"
else
	error("Unsupported emulator")
end

-- Replacements for lua 5.3 bitwise operators since desmume uses lua 5.1 and would throw a fit
local function bit_and(a, b)
	local result = 0
	local power = 1
	while (a > 0 and b > 0) do
		if (a % 2 == 1 and b % 2 == 1) then
			--return 1 + 2 * bit_and(math.floor(a / 2), math.floor(b / 2))
			result = result + power
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
		power = power * 2
	end
	return result
end
-- local function bit_or(a, b) return a + b - bit_and(a, b) end
-- local function bit_not(a) return 0xFFFFFFFF - a end  -- 2^32 - 1 for 32-bit mask

local function RGBA_to_ARGB(rgba_str)
	-- local rgba_str = string.format("%x", rgba)
	local a_str = string.sub(rgba_str, 9)
	local rgb_str = string.sub(rgba_str, 3, 8)
	local argb_str = "0x" .. a_str .. rgb_str
	return argb_str
end


-- must fill in these functions for each emulator:
local api = {
	-- memory
	mem = {
		-- read
		r = {
			-- unsigned
			u = {
				[8] = nil,
				[16] = nil,
				[32] = nil
			},
			-- signed
			s = {
				[8] = nil,
				[16] = nil,
				[32] = nil
			}
		},
		-- write
		w = {
			-- unsigned
			u = {
				[8] = nil,
				[16] = nil,
				[32] = nil
			},
			-- signed
			s = {
				[8] = nil,
				[16] = nil,
				[32] = nil
			}
		},
	},
	-- joypad
	joy = {
		-- get buttons
		get = {
			up = nil,
			down = nil,
			left = nil,
			right = nil,
			a = nil,
			b = nil,
			x = nil,
			y = nil,
			l = nil,
			r = nil,
			start = nil,
			select = nil
		}
		-- set buttons? (unused for now)
		-- set = nil,
	},
	gui = {
		rect = nil,
		clear = function() end -- not required
	}
}

if emu_name == "bizhawk" then
	api.mem.r.u[8]     = memory.read_u8
	api.mem.r.s[8]     = memory.read_s8
	api.mem.r.u[16]    = memory.read_u16_le
	api.mem.r.s[16]    = memory.read_s16_le
	api.mem.r.u[32]    = memory.read_u32_le
	api.mem.r.s[32]    = memory.read_s32_le
	api.mem.w.u[8]     = memory.write_u8
	api.mem.w.s[8]     = memory.write_s8
	api.mem.w.u[16]    = memory.write_u16_le
	api.mem.w.s[16]    = memory.write_s16_le
	api.mem.w.u[32]    = memory.write_u32_le
	api.mem.w.s[32]    = memory.write_s32_le
	api.joy.get.up     = function() return joypad.get().Up end
	api.joy.get.down   = function() return joypad.get().Down end
	api.joy.get.left   = function() return joypad.get().Left end
	api.joy.get.right  = function() return joypad.get().Right end
	api.joy.get.a      = function() return joypad.get().A end
	api.joy.get.b      = function() return joypad.get().B end
	api.joy.get.x      = function() return joypad.get().X end
	api.joy.get.y      = function() return joypad.get().Y end
	api.joy.get.l      = function() return joypad.get().L end
	api.joy.get.r      = function() return joypad.get().R end
	api.joy.get.start  = function() return joypad.get().Start end
	api.joy.get.select = function() return joypad.get().Select end
	api.gui.rect       = function(args)
		local x = args.x -- coordinate of topleft corner
		local y = args.y
		local w = args.w -- width
		local h = args.h -- height
		-- constrain to boundaries of the screen
		-- (first check that any of the hitbox would be in the screen)
		if x > 255 or y > 191 or x + w < 0 or y + h < 0 then return end
		if x < 0 then
			w = w + x
			x = 0
		end
		if y < 0 then
			h = h + y
			y = 0
		end
		if x + w > 255 then w = 255 - x end
		if y + h > 191 then h = 191 - y end
		-- colors are passed in as RGBA, but bizhawk uses ARGB
		local line = args.line ~= nil and tonumber(RGBA_to_ARGB(args.line)) or 0xFFFFFFFF
		local fill = args.fill ~= nil and tonumber(RGBA_to_ARGB(args.fill)) or 0x00000000

		if (nds.getscreenlayout() == "Hybrid") then
			-- draw rectangle for the small upper screen
			local adj_x = x + (256 * 2)
			--print(adj_x .. ", " .. y .. "; " .. w .. ", " .. h)
			gui.drawRectangle(adj_x, y, w, h, line, fill)

			-- draw rectangle for the big main screen
			local adj_x = x * 2
			local adj_y = y * 2
			local adj_w = w * 2 + 1
			local adj_h = h * 2 + 1
			gui.drawRectangle(adj_x, adj_y, adj_w, adj_h, line, fill)
			--print(adj_x .. ", " .. adj_y .. "; " .. adj_w .. ", " .. adj_h)
		elseif (nds.getscreenlayout() ~= "Bottom Only") then
			-- all other layouts are simple
			gui.drawRectangle(x, y, w, h, line, fill)
		end
	end
	api.gui.clear      = gui.clearGraphics
elseif emu_name == "desmume" then
	api.mem.r.u[8]     = memory.readbyte
	api.mem.r.s[8]     = memory.readbytesigned
	api.mem.r.u[16]    = memory.readword
	api.mem.r.s[16]    = memory.readwordsigned
	api.mem.r.u[32]    = memory.readdword
	api.mem.r.s[32]    = memory.readdwordsigned
	api.mem.w.u[8]     = memory.writebyte
	api.mem.w.s[8]     = memory.writebyte
	api.mem.w.u[16]    = memory.writeword
	api.mem.w.s[16]    = memory.writeword
	api.mem.w.u[32]    = memory.writedword
	api.mem.w.s[32]    = memory.writedword
	api.joy.get.up     = function() return joypad.get(1).up end
	api.joy.get.down   = function() return joypad.get(1).down end
	api.joy.get.left   = function() return joypad.get(1).left end
	api.joy.get.right  = function() return joypad.get(1).right end
	api.joy.get.a      = function() return joypad.get(1).A end
	api.joy.get.b      = function() return joypad.get(1).B end
	api.joy.get.x      = function() return joypad.get(1).X end
	api.joy.get.y      = function() return joypad.get(1).Y end
	api.joy.get.l      = function() return joypad.get(1).L end
	api.joy.get.r      = function() return joypad.get(1).R end
	api.joy.get.start  = function() return joypad.get(1).start end
	api.joy.get.select = function() return joypad.get(1).select end
	api.gui.rect       = function(args)
		local x = args.x
		local y = args.y
		local w = args.w
		local h = args.h
		-- colors are RGBA
		local line = args.line ~= nil and tonumber(args.line) or 0x00FFFFFF
		local fill = args.fill ~= nil and tonumber(args.fill) or 0x00000000
		-- desmume uses signed numbers or something so red channel cannot be >=50%
		if line > 0x7FFFFFFF then
			-- line = 0x00FFFFFF
			line = line % 0x80000000
		end
		if fill > 0x7FFFFFFF then
			-- fill = 0x00FFFF40
			fill = fill % 0x80000000
		end

		local x1 = x
		local y1 = y - 192
		local x2 = x1 + w
		local y2 = y1 + h
		gui.rect(x1, y1, x2, y2, fill, line)
		-- print("rect(".. x1 ..", ".. y1 ..", ".. x2 ..",".. y2 ..")")
	end
elseif emu_name == "drastic" then
	api.mem.r.u[8]     = drastic.get_ds_memory_arm9_8
	api.mem.r.s[8]     = drastic.get_ds_memory_arm9_8
	api.mem.r.u[16]    = drastic.get_ds_memory_arm9_16
	api.mem.r.s[16]    = drastic.get_ds_memory_arm9_16
	api.mem.r.u[32]    = drastic.get_ds_memory_arm9_32
	api.mem.r.s[32]    = drastic.get_ds_memory_arm9_32
	api.mem.w.u[8]     = drastic.set_ds_memory_arm9_8
	api.mem.w.s[8]     = drastic.set_ds_memory_arm9_8
	api.mem.w.u[16]    = drastic.set_ds_memory_arm9_16
	api.mem.w.s[16]    = drastic.set_ds_memory_arm9_16
	api.mem.w.u[32]    = drastic.set_ds_memory_arm9_32
	api.mem.w.s[32]    = drastic.set_ds_memory_arm9_32
	api.joy.get.up     = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_UP) ~= 0) end
	api.joy.get.down   = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_DOWN) ~= 0) end
	api.joy.get.left   = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_LEFT) ~= 0) end
	api.joy.get.right  = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_RIGHT) ~= 0) end
	api.joy.get.a      = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_A) ~= 0) end
	api.joy.get.b      = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_B) ~= 0) end
	api.joy.get.x      = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_X) ~= 0) end
	api.joy.get.y      = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_Y) ~= 0) end
	api.joy.get.l      = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_L) ~= 0) end
	api.joy.get.r      = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_R) ~= 0) end
	api.joy.get.start  = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_START) ~= 0) end
	api.joy.get.select = function() return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_SELECT) ~= 0) end
	-- joy.set is unused rn but these are proof of concept
	-- api.joy.set.left    = function (pressed) return drastic.set_buttons(pressed and bit_or(drastic.get_buttons(), drastic.C.BUTTON_LEFT) or bit_and(drastic.get_buttons(), bit_not(drastic.C.BUTTON_LEFT))) end
	-- api.joy.set.right   = function (pressed) return drastic.set_buttons(pressed and bit_or(drastic.get_buttons(), drastic.C.BUTTON_RIGHT) or bit_and(drastic.get_buttons(), bit_not(drastic.C.BUTTON_RIGHT))) end
end

-- the following function definitions are for DraStic compatibility
--playing_zx = true
function on_load(game)
	-- if "ZX" in game and not ("ZXA" in game or "zxa" in game or "advent" in game or "Advent" in game or "ADVENT" in game)
	-- 	playing_zx = true
	-- end
end

function on_unload()
	-- if not ("ZX" in game and not ("ZXA" in game or "zxa" in game or "advent" in game or "Advent" in game or "ADVENT" in game))
	-- 	playing_zx = false
	-- end
end

------------------------------- END API HANDLER LAYER -------------------------------


--Hopefully this is consistent for determining game version
local jp
local function set_version()
	if api.mem.r.u[16](0x0200000E) == 0x333B then
		jp = false
		print("en")
	else
		jp = true
		print("jp")
	end
end

-- important addresses in memory
local adr = {}
-- all JP are -400 from EN, unless marked, or the bottom several (attack data) which are -30
--  Could maybe just assume -400 unless specified
local function init_adr()
	adr = {
		input = 0x04000130,                         -- readonly. 0x03FF by default, each input toggles off a certain bit
		equipped_chips = jp and 0x0214F8AC or 0x0214FCAC, --jp guessed
		model = jp and 0x0214F874 or 0x0214FC74,
		definite_model = jp and 0x020F457C or 0x020F73AC, --not same thing as en one but should work
		current_model_WE_cap = jp and 0x0214FE75 or 0x02150275,
		HX_WE = jp and 0x0214F895 or 0x0214FC95,
		FX_WE = jp and 0x0214F896 or 0x0214FC96,
		LX_WE = jp and 0x0214F897 or 0x0214FC97,
		PX_WE = jp and 0x0214F898 or 0x0214FC98,
		current_model_WE = jp and 0x0214FE71 or 0x02150271,
		--0=ground, 1=air, 2=wall, 4=swim?
		grounded_state = jp and 0x0214F719 or 0x0214FB19,
		--65 or 67 if overdrive active
		overdrive = jp and 0x0214F82D or 0x0214FC2D,
		-- velocities are local, e.g. they stay 0 while standing still on a moving platform
		x_vel = jp and 0x0214F76C or 0x0214FB6C,
		y_vel = jp and 0x0214F770 or 0x0214FB70,
		last_ability_id = jp and 0x0214F836 or 0x0214FC36,
		action_id = jp and 0x0214F848 or 0x0214FC48,
		x_pos = jp and 0x0214F764 or 0x0214FB64, -- JP wasn't set before? probably mistake
		y_pos = jp and 0x0214F768 or 0x0214FB68,
		--last_platform_y = 0x020F1FD4 --probably not legit
		main_charge = jp and 0x0214F838 or 0x0214FC38,
		sub_charge = jp and 0x0214F839 or 0x0214FC39,
		lx_sled_1_vel = jp and 0x02150494 or 0x02150894,
		lx_sled_2_vel = jp and 0x021503C4 or 0x021507C4,
		lx_sled_3_vel = jp and 0x021502F4 or 0x021506F4,
		px_kunai_angles = jp and 0x0218BA1C or 0x0218BA1C, -- same as en?
		px_num_kunai_in_last = jp and 0x0214FA0A or 0x0214FE0A,
		priority = jp and 0x02150C9E or 0x0215109E,
		-- palette for model x; all others are offset
		x_palette = jp and 0x020DA9E2 or 0x020DE7C6,       -- JP = EN - 3DE4
		-- starts on first non-transparent color
		current_model_palette = jp and 0x020F79CA or 0x020F5C4A, -- JP = EN + 1D80
		-- center of screen
		camera_x = jp and 0x0214F22C or 0x0214F62C,
		camera_y = jp and 0x0214F230 or 0x0214F630,
		-- animation id (e.g. "jumping", "falling")
		anim_id = jp and 0x0214F780 or 0x0214FB80,
		--current frame of animation (current sprite)
		anim_frame = jp and 0x0214F781 or 0x0214FB81,
		--how many ingame frames til next anim frame/sprite
		anim_frame_timer = jp and 0x0214F782 or 0x0214FB82,
		hurtbox_ptr = jp and 0x0214F784 or 0x0214FB84,
		--maybe better is 0x0214FC64?
		current_room = jp and 0x02107E28 or 0x02108228,
		--actually some sorta animation id but 27 is used when transerver
		something_transerver = jp and 0x0214F848 or 0x0214FC48,
		player_hp = jp and 0x0214F7B2 or 0x0214FBB2, -- guessed?
		-- (currently unused)
		max_hp = 0x0214FC76,
		--each word is each model's main/sub wep ending in OX at EN:0214FC8E. Hu:00, X:01, ZX-saber:02, ZX-buster:03, HX-slash:04, HX-slice:05, FX-left:06, FX-right:07, LX:08, PX:09, OX-saber:0A, OX-buster:0B
		-- (currently unused)
		weapon_bindings = jp and 0x0214F880 or 0x0214FC80,
		--each word is a button starting here ending with overdrive at EN:0214FCC2: main, sub, jump, dash, transform, overdrive. buttons: A:0001, B:0002, R:0100, L:0200, X:0400, Y:0800
		control_bindings = jp and 0x0214F8B8 or 0x0214FCB8,
		--0 type A, 1 type B, 2 custom
		control_type = jp and 0x0214F8C4 or 0x0214FCC4,
		--0 thru 4 starting at main
		pause_menu_page = jp and 0x0215EC1D or 0x0215F01D,
		--192 (jp: 64) if paused (doesn't include other menus like main or file), 184 (jp: 56) otherwise
		is_paused = jp and 0x0214FE3C or 0x0215023C,
		-- weird address storing various current/recent movement data... 1st bit is whether dash is currently active (not including swimdash)
		movement_info = jp and 0x0214F82C or 0x0214FC2C,
		--4: swimming or post-HX-dash; 12: HX horizontal airdash; 20: HX vertical airdash or swimdash
		dash_type = jp and 0x0214F82F or 0x0214FC2F,
		dash_frames_remaining = jp and 0x0214F830 or 0x0214FC30,
		-- all the below have JP -30 offset instead of -400
		final_attack_slot_attack_id = jp and 0x02159201 or 0x02159231,
		final_attack_slot_angle = jp and 0x02159218 or 0x02159248,
		final_attack_slot_x = jp and 0x02159248 or 0x02159278,
		final_attack_slot_y = jp and 0x0215924C or 0x0215927C,
		final_attack_slot_direction = jp and 0x02159252 or 0x02159282, --00 = right, FF = left
		final_attack_slot_overdrive = jp and 0x0215929E or 0x021592CE,
		final_attack_slot_element = jp and 0x021592A0 or 0x021592D0,
		--was "active" but realized it only applies to 1 at a time
		-- (currently unused)
		final_attack_slot_primary = jp and 0x021591ED or 0x0215921D,
		--if val modulus 0x10 == 0xF then active (unless 8F?), otherwise 0xA
		final_attack_slot_active_direction = jp and 0x021591F6 or 0x02159226,
		final_attack_slot_anim_frame = jp and 0x02159265 or 0x02159295,
		final_attack_slot_anim_something = jp and 0x02159268 or 0x02159298,
		final_atk_hitbox_ptr_tracker_ptr = jp and 0x02108734 or 0x02108B34, -- jp guessed
		final_hitbox_ptr_tracker_ptr = jp and 0x02108738 or 0x02108B38,   -- jp guessed
		final_player_hurtbox_ptr_tracker_ptr = jp and 0x02108740 or 0x02108B40, -- jp guessed
		-- final_enemy_hurtbox_ptr_tracker_ptr = jp and 0x02154ACC or 0x02154ECC, -- jp guessed
		final_enemy_hurtbox_ptr_tracker_ptr = jp and 0x02108744 or 0x02108B44, -- jp guessed
		dash_pal_start = jp and 0x020F79EA or 0x020F5C6A,

		-- individual hitbox data
		hb_lx_something = jp and 0x0218CCA0 or 0x0218CFA0, -- jp guessed

		-- currently unused:

		player_iframes = jp and 0x0214F7A4 or 0x0214FBA4,
		--001FFFFF for all A and B items; +0x00020000 for quick charge
		acquired_items = 0x0210461C,
		--lvl 0 to 4. 4 hivolt, 5 lurerre, 6 fistleo, 7 purprill, 8 hurricaune, 9 leganchor, A flammole, B protectos
		boss_lvls = 0x02104634,
		boss_iframes = 0x0215109C,
		prometheus_iframes = 0x02150E9C,
		pandora_iframes = 0x02150F9C,
	}
end
--A:0001, B:0002, R:0100, L:0200, X:0400, Y:0800
--main, sub, jump, dash, transform, overdrive
local controls = { 'Y', 'R', 'B', 'L', 'X', 'A' }
local function read_controls()
	if api.mem.r.u[8](adr.control_type) == 0 then  --type A
		controls = { 'Y', 'R', 'B', 'L', 'X', 'A' }
	elseif api.mem.r.u[8](adr.control_type) == 1 then --type B
		controls = { 'Y', 'X', 'B', 'A', 'L', 'R' }
	else                                           --custom
		local button
		for i = 1, 6, 1 do
			button = api.mem.r.u[16](adr.control_bindings + i * 0x2)
			if button == 0x0001 then
				controls[i] = 'A'
			elseif button == 0x0002 then
				controls[i] = 'B'
			elseif button == 0x0100 then
				controls[i] = 'R'
			elseif button == 0x0200 then
				controls[i] = 'L'
			elseif button == 0x0400 then
				controls[i] = 'X'
			elseif button == 0x0800 then
				controls[i] = 'Y'
			end
		end
	end
end
-- get the state of an input based on its action, so it should work regardless of control scheme
local function read_button(action)
	local action_index
	if action == "main" then
		action_index = 1
	elseif action == "sub" then
		action_index = 2
	elseif action == "jump" then
		action_index = 3
	elseif action == "dash" then
		action_index = 4
	elseif action == "transform" then
		action_index = 5
	elseif action == "overdrive" then
		action_index = 6
	end
	if controls[action_index] == "A" then
		return api.joy.get.a()
	elseif controls[action_index] == "B" then
		return api.joy.get.b()
	elseif controls[action_index] == "R" then
		return api.joy.get.r()
	elseif controls[action_index] == "L" then
		return api.joy.get.l()
	elseif controls[action_index] == "X" then
		return api.joy.get.x()
	elseif controls[action_index] == "Y" then
		return api.joy.get.y()
	end
	return false
end

local chip_value
local function determine_quickcharge_equipped(n)
	if n == nil then
		n = 128
		chip_value = api.mem.r.u[8](adr.equipped_chips)
	end
	if (chip_value - n) >= 0 then
		chip_value = chip_value - n
		if n == 8 then
			n = nil
			return true
		end
	end
	if n == 0 then --if reached end, return false
		n = nil
		return false
	end
	return determine_quickcharge_equipped(math.floor(n / 2))
end

--just used within other functions for determining needed charge times
local function max_charge_frames(lvl) --parameter 1 for lvl 1 charge or 2 for lvl2
	if determine_quickcharge_equipped() == false then
		if lvl == 2 then
			return 120
		else
			return 40
		end
	else
		if lvl == 2 then
			return 96
		else
			return 32
		end
	end
end


local model_switch_pressed = false
local function model_switch()
	local current_model = api.mem.r.u[8](adr.model)
	local switch_pressed = api.joy.get.select() and (api.joy.get.left() or api.joy.get.right())
	if switch_pressed and not model_switch_pressed then
		local next_model = current_model
		if api.joy.get.left() then
			next_model = current_model - 1
		elseif api.joy.get.right() then
			next_model = current_model + 1
		end
		next_model = next_model % 8
		if next_model ~= current_model then
			api.mem.w.u[8](adr.model, next_model)
		end
	end
	model_switch_pressed = switch_pressed
end


-- hitbox_text_num = 0

local function calc_hitbox_bounds(hitbox_tracker_ptr, cam_pos_x, cam_pos_y, next_frame_hitboxes, line, fill) -- helper function for the below function
	local hitbox_tracker_info = api.mem.r.u[32](hitbox_tracker_ptr)
	-- print("hitbox_tracker_info: " .. string.format("%x", hitbox_tracker_info))
	while hitbox_tracker_info ~= 0x00000000 do
		-- attack coords relative to center of screen
		-- note: x+ = right, y+ = down
		local x_pos = api.mem.r.u[32](hitbox_tracker_info + 0xC)
		local y_pos = api.mem.r.u[32](hitbox_tracker_info + 0x10)
		local width = api.mem.r.u[16](hitbox_tracker_info + 0x14)
		local height = api.mem.r.u[16](hitbox_tracker_info + 0x16)
		local cam_offset_x = x_pos - cam_pos_x
		local cam_offset_y = y_pos - cam_pos_y
		-- convert to relative to topleft of top screen
		local rect_center_x = cam_offset_x + 128 * 0x100
		local rect_center_y = cam_offset_y + 96 * 0x100
		local topleft_x = rect_center_x - (width / 2)
		local topleft_y = rect_center_y - (height / 2)
		-- change color based on hitbox properties
		local temp_line = line
		local temp_fill = fill
		local hitbox_info_addr = api.mem.r.u[32](hitbox_tracker_info + 0x4)
		local is_hurtbox = api.mem.r.u[32](hitbox_info_addr + 0x4) == 0xFFFFFFFF
		if is_hurtbox then
			local hurtbox_is_invuln = bit_and(api.mem.r.u[32](hitbox_info_addr + 0xC), 0xFFFFFFFF) == 0xFFFFFFFF
			local hurtbox_is_weakpoint = bit_and(api.mem.r.u[8](hitbox_info_addr + 0x9), 0x80) == 0x80
			local hurtbox_element = api.mem.r.u[8](hitbox_info_addr + 0x8)
			if hurtbox_is_invuln then
				temp_line = "0x000000FF"
			elseif hurtbox_is_weakpoint then
				temp_line = "0xFFFFFFFF"
			elseif hurtbox_element == 2 or hurtbox_element == 6 then -- electric
				temp_line = "0xC8FF00FF"
			elseif hurtbox_element == 3 or hurtbox_element == 7 then -- fire
				temp_line = "0xFFC000FF"
			elseif hurtbox_element == 4 or hurtbox_element == 8 then -- ice
				temp_line = "0x0080FFFF"
			end
		else
			local hitbox_is_harmless = api.mem.r.u[8](hitbox_info_addr + 0x3) == 0xFF
			local hitbox_element = api.mem.r.u[8](hitbox_info_addr + 0x5)
			if hitbox_element == 0 then
				local attack_slot_addr = api.mem.r.u[32](hitbox_tracker_info + 0x8)
				if bit_and(api.mem.r.u[8](attack_slot_addr + 0x39), 0x01) == 0x01 then
					local attack_element = api.mem.r.u[8](attack_slot_addr + 0x38)
					if attack_element >= 0 and attack_element <= 3 then
						hitbox_element = attack_element
					end
				end
			end
			if hitbox_is_harmless then
				temp_line = "0xFF00FFFF"
				temp_fill = "0xFF00FF20"
			elseif hitbox_element == 0 then -- normal
				-- temp_line = "0xF0F0F0FF"
			elseif hitbox_element == 1 then -- electric
				-- temp_line = "0x40FF00FF"
				temp_fill = "0x40FF0040"
			elseif hitbox_element == 2 then -- fire
				-- temp_line = "0xFF8000FF"
				temp_fill = "0xFF800040"
			elseif hitbox_element == 3 then -- ice
				-- temp_line = "0x0040FFFF"
				temp_fill = "0x0040FF40"
			end
		end
		-- display hitbox info text
		-- local left = x_pos - width/2
		-- local right = x_pos + width/2
		-- local top = y_pos - height/2
		-- local bot = y_pos + height/2
		-- local left_px = math.ceil(topleft_x / 0x100)
		-- local right_px = math.ceil(topleft_x / 0x100) + math.floor(width / 0x100 + 0.5) - 1
		-- local top_px = math.ceil(topleft_y / 0x100)
		-- local bot_px = math.ceil(topleft_y / 0x100) + math.floor(height / 0x100 + 0.5) - 1
		-- local correct_px_width = (right - left) / 0x100
		-- local correct_px_height = (bot - top) / 0x100
		-- local displayed_px_width = right_px - left_px
		-- local displayed_px_height = bot_px - top_px
		-- local print_color = is_hurtbox and 0xFFC0FFC0 or 0xFFFFC0C0
		-- gui.drawText(15, 346-30*hitbox_text_num, string.format("%x %3d %2d  |  %x %3d %2d", left, left_px, correct_px_width, top, top_px, correct_px_height), print_color, 0xFF000000)
		-- gui.drawText(15, 356-30*hitbox_text_num, string.format("%x %3d %2d  |  %x %3d %2d", right, right_px, displayed_px_width+1, bot, bot_px, displayed_px_height+1), print_color, 0xFF000000)
		-- hitbox_text_num = hitbox_text_num + 1

		-- print("hitbox_tracker_info: " .. string.format("%x", hitbox_tracker_info))
		-- print("pos: (" .. string.format("%x", x_pos) .. ", " .. string.format("%x", y_pos) .. ")")
		-- print("size: " .. width .. " x " .. height)
		-- print("camera offset: " .. cam_offset_x .. ", " .. cam_offset_y)
		-- print("rect center: " .. rect_center_x .. ", " .. rect_center_y)
		-- print("topleft: " .. math.floor(topleft_x + 0.5) .. "," .. math.floor(topleft_y + 0.5))
		next_frame_hitboxes[#next_frame_hitboxes + 1] = {
			x = math.floor((topleft_x + 0.5) / 0x100),
			y = math.floor((topleft_y + 0.5) / 0x100),
			w = math.floor(width / 0x100 + 0.5) - 1,
			h = math.floor(height / 0x100 + 0.5) - 1,
			line = temp_line,
			fill = temp_fill
		}
		-- continue to the next hitbox
		hitbox_tracker_info = api.mem.r.u[32](hitbox_tracker_info)
	end
end
local prev_frame_hitboxes = {}
local enable_hitbox_viewer = false
local enable_hitbox_viewer_pressed = false
local function display_collision_contact()
	local contact_state = api.mem.r.u[8](adr.grounded_state)
	if contact_state == 1 or contact_state == 4 then
		return
	end

	local cam_pos_x = api.mem.r.u[32](adr.camera_x)
	local cam_pos_y = api.mem.r.u[32](adr.camera_y)
	local player_x = api.mem.r.u[32](adr.x_pos)
	local player_y = api.mem.r.u[32](adr.y_pos)
	local screen_x = (player_x - cam_pos_x) / 0x100 + 128
	local screen_y = (player_y - cam_pos_y) / 0x100 + 96

	if contact_state == 0 then
		api.gui.rect({
			x = math.floor(screen_x - 8),
			y = math.floor(screen_y),
			w = 16,
			h = 2,
			line = "0x00FFFFFF",
			fill = "0x00FF0080"
		})
	elseif contact_state == 3 then
		api.gui.rect({
			x = math.floor(screen_x - 8),
			y = math.floor(screen_y - 8),
			w = 16,
			h = 2,
			line = "0xFFFFFFFF",
			fill = "0xFFFFFF80"
		})
	end
end
local function display_hitboxes()
	-- Enable with Select+B
	if api.joy.get.select() and api.joy.get.b() then
		if not enable_hitbox_viewer_pressed then
			enable_hitbox_viewer = not enable_hitbox_viewer
			if not enable_hitbox_viewer then
				api.gui.clear()
			end
		end
		enable_hitbox_viewer_pressed = true
	else
		enable_hitbox_viewer_pressed = false
	end
	if enable_hitbox_viewer then
		api.gui.clear()

		-- hitbox_text_num = 0

		-- render hitboxes cached from previous frame
		if #prev_frame_hitboxes > 0 then
			for _, box in pairs(prev_frame_hitboxes) do
				-- api.gui.rect(box.x1, box.y1, box.x2, box.y2)
				api.gui.rect(box)
			end
		end
		local pause_state = api.mem.r.u[8](adr.is_paused)
		local paused_value = jp and 64 or 192
		if pause_state ~= paused_value then
			display_collision_contact()
		end

		local next_frame_hitboxes = {}
		local cam_pos_x = api.mem.r.u[32](adr.camera_x)
		local cam_pos_y = api.mem.r.u[32](adr.camera_y)
		-- display camera coords
		-- gui.drawText(15, 368, string.format("%x         |  %x", cam_pos_x, cam_pos_y), nil, 0xFF000000)

		-- general hitboxes
		calc_hitbox_bounds(
			adr.final_hitbox_ptr_tracker_ptr,
			cam_pos_x, cam_pos_y,
			next_frame_hitboxes,
			"0xFF0000FF", "0xFF000040"
		)

		-- enemy hurtboxes
		calc_hitbox_bounds(
			adr.final_enemy_hurtbox_ptr_tracker_ptr,
			cam_pos_x, cam_pos_y,
			next_frame_hitboxes,
			"0xFFFF00FF", 0
		)

		-- player hurtbox
		calc_hitbox_bounds(
			adr.final_player_hurtbox_ptr_tracker_ptr,
			cam_pos_x, cam_pos_y,
			next_frame_hitboxes,
			"0x00FF00FF", 0
		)

		-- player hitboxes
		calc_hitbox_bounds(
			adr.final_atk_hitbox_ptr_tracker_ptr,
			cam_pos_x, cam_pos_y,
			next_frame_hitboxes,
			"0x00FFFFFF", 0
		)

		prev_frame_hitboxes = next_frame_hitboxes
	end
end

local collision_map = {}
local collision_map_room = nil
local function display_collision_map()
	local pause_state = api.mem.r.u[8](adr.is_paused)
	local paused_value = jp and 64 or 192
	if pause_state == paused_value then
		return
	end

	local room = api.mem.r.u[32](adr.current_room)
	if collision_map_room ~= room then
		collision_map = {}
		collision_map_room = room
	end

	local contact_state = api.mem.r.u[8](adr.grounded_state)
	if contact_state == 0 or contact_state == 2 or contact_state == 3 then
		local player_x = api.mem.r.u[32](adr.x_pos)
		local player_y = api.mem.r.u[32](adr.y_pos)
		local world_x = math.floor(player_x / 0x100 + 0.5)
		local world_y = math.floor(player_y / 0x100 + 0.5)
		if contact_state == 2 then
			if api.joy.get.left() then
				world_x = world_x - 12
			elseif api.joy.get.right() then
				world_x = world_x + 10
			else
				local x_velocity = api.mem.r.s[32](adr.x_vel)
				if x_velocity < 0 then
					world_x = world_x - 12
				elseif x_velocity > 0 then
					world_x = world_x + 10
				end
			end
		end
		local point_key = world_x .. ":" .. world_y .. ":" .. contact_state

		if collision_map[point_key] == nil then
			collision_map[point_key] = {
				x = world_x,
				y = world_y,
				state = contact_state
			}
		end
	end

	local cam_pos_x = api.mem.r.u[32](adr.camera_x) / 0x100
	local cam_pos_y = api.mem.r.u[32](adr.camera_y) / 0x100
	for _, point in pairs(collision_map) do
		local screen_x = point.x - cam_pos_x + 128
		local screen_y = point.y - cam_pos_y + 96
		local color = point.state == 0 and "0x00FFFFFF"
			or point.state == 2 and "0xFFFF00FF"
			or "0xFFFFFFFF"

		api.gui.rect({
			x = math.floor(screen_x),
			y = math.floor(screen_y),
			w = 0,
			h = 0,
			line = color,
			fill = color
		})
	end
end

local display_information_pressed = false
local previous_displayed_info = 2
local displayed_info = 2 -- 0 = none, 1 = velocity, 2 = position, 3 = collision map
local function display_information()
	local switch_pressed = api.joy.get.select() and api.joy.get.a()
	if switch_pressed and not display_information_pressed then
		displayed_info = (displayed_info + 1) % 4
	end
	display_information_pressed = switch_pressed

	if previous_displayed_info == 3 and displayed_info ~= 3 then
		api.gui.clear()
	end
	previous_displayed_info = displayed_info

	if displayed_info == 0 then
		return
	elseif displayed_info == 1 then
		local current_x_vel = api.mem.r.s[32](adr.x_vel) / 256.0
		local current_y_vel = api.mem.r.s[32](adr.y_vel) / 256.0
		gui.text(10, 20, string.format("Velocity: (%0.3f, %0.3f)", current_x_vel, current_y_vel), "white", "black")
	elseif displayed_info == 2 then
		local current_x = api.mem.r.u[32](adr.x_pos) / 256.0
		local current_y = api.mem.r.u[32](adr.y_pos) / 256.0
		gui.text(10, 20, string.format("Position: (%0.4f, %0.4f)", current_x, current_y), "white", "black")
	elseif displayed_info == 3 then
		gui.text(10, 20, "Collision map: recording contact points", "white", "black")
	end
end

--MAIN
local started = false
local function mods()
	if not started then
		if emu_name == "bizhawk" then console.clear() end
		print(emu_name)
		set_version()
		init_adr()
		read_controls()
		--print(string.format("model: %x", adr.model))
		started = true
	end
	-- event.onframestart(function () api.gui.clear() end)

	if api.mem.r.u[8](adr.pause_menu_page) == 2 then
		read_controls()
	end

	-- Comment out any of these you dont want to use!
	--  Just add two hyphens to the start of the line(s)


	model_switch() -- press Select + another button to instantly switch model
	-- L: X, R: ZX, Up: HX, Down: FX, Left: LX, Right: PX, A: OX

	if emu_name ~= "drastic" then
		display_hitboxes()
		-- actively render hitboxes onscreen
		-- enable in-game with Select+B
		-- green: player hurtbox
		-- yellow: enemy hurtboxes
		-- (hurtboxes can also be black if invulnerable, or white if weakpoint, or orange/green/blue for elemental type)
		-- cyan: player attacks
		-- (slight orange/green/blue fill for elements)
		-- red (with transparent red fill): enemy damage hitboxes
		-- pink: non-damaging hitboxes (pickups)
		-- Desmume note: most of these colors are totally off on desmume due to a bug with its API
	end

	display_information() -- displays velocity, position, or collision-map status
	if displayed_info == 3 then
		display_collision_map()
	end
end

-- define loop for drastic
function on_frame_update()
	mods()
end

-- define loop for desmume/bizhawk
if emu_name == "bizhawk" or emu_name == "desmume" then
	while true do
		mods()
		emu.frameadvance()
	end
end
