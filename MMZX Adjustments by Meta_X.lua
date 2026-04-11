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

emu_name = ""
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
function bit_and(a, b)
	result = 0
	power = 1
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

function RGBA_to_ARGB(rgba_str)
	-- local rgba_str = string.format("%x", rgba)
	local a_str = string.sub(rgba_str, 9)
	local rgb_str = string.sub(rgba_str, 3, 8)
	local argb_str = "0x" ..  a_str .. rgb_str
	return argb_str
end


-- must fill in these functions for each emulator:
api = {
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
		clear = function () end -- not required
	}
}

if emu_name == "bizhawk" then
	api.mem.r.u[8] = memory.read_u8
	api.mem.r.s[8] = memory.read_s8
	api.mem.r.u[16] = memory.read_u16_le
	api.mem.r.s[16] = memory.read_s16_le
	api.mem.r.u[32] = memory.read_u32_le
	api.mem.r.s[32] = memory.read_s32_le
	api.mem.w.u[8] = memory.write_u8
	api.mem.w.s[8] = memory.write_s8
	api.mem.w.u[16] = memory.write_u16_le
	api.mem.w.s[16] = memory.write_s16_le
	api.mem.w.u[32] = memory.write_u32_le
	api.mem.w.s[32] = memory.write_s32_le
	api.joy.get.up 		= function () return joypad.get().Up end
	api.joy.get.down 	= function () return joypad.get().Down end
	api.joy.get.left 	= function () return joypad.get().Left end
	api.joy.get.right 	= function () return joypad.get().Right end
	api.joy.get.a 		= function () return joypad.get().A end
	api.joy.get.b 		= function () return joypad.get().B end
	api.joy.get.x 		= function () return joypad.get().X end
	api.joy.get.y 		= function () return joypad.get().Y end
	api.joy.get.l 		= function () return joypad.get().L end
	api.joy.get.r 		= function () return joypad.get().R end
	api.joy.get.start 	= function () return joypad.get().Start end
	api.joy.get.select 	= function () return joypad.get().Select end
	api.gui.rect = function (args)
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
	api.gui.clear = gui.clearGraphics
elseif emu_name == "desmume" then
	api.mem.r.u[8] = memory.readbyte
	api.mem.r.s[8] = memory.readbytesigned
	api.mem.r.u[16] = memory.readword
	api.mem.r.s[16] = memory.readwordsigned
	api.mem.r.u[32] = memory.readdword
	api.mem.r.s[32] = memory.readdwordsigned
	api.mem.w.u[8] = memory.writebyte
	api.mem.w.s[8] = memory.writebyte
	api.mem.w.u[16] = memory.writeword
	api.mem.w.s[16] = memory.writeword
	api.mem.w.u[32] = memory.writedword
	api.mem.w.s[32] = memory.writedword
	api.joy.get.up 		= function () return joypad.get(1).up end
	api.joy.get.down 	= function () return joypad.get(1).down end
	api.joy.get.left 	= function () return joypad.get(1).left end
	api.joy.get.right 	= function () return joypad.get(1).right end
	api.joy.get.a 		= function () return joypad.get(1).A end
	api.joy.get.b 		= function () return joypad.get(1).B end
	api.joy.get.x 		= function () return joypad.get(1).X end
	api.joy.get.y 		= function () return joypad.get(1).Y end
	api.joy.get.l 		= function () return joypad.get(1).L end
	api.joy.get.r 		= function () return joypad.get(1).R end
	api.joy.get.start 	= function () return joypad.get(1).start end
	api.joy.get.select 	= function () return joypad.get(1).select end
	api.gui.rect = function (args) 
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
	api.mem.r.u[8] = drastic.get_ds_memory_arm9_8
	api.mem.r.s[8] = drastic.get_ds_memory_arm9_8
	api.mem.r.u[16] = drastic.get_ds_memory_arm9_16
	api.mem.r.s[16] = drastic.get_ds_memory_arm9_16
	api.mem.r.u[32] = drastic.get_ds_memory_arm9_32
	api.mem.r.s[32] = drastic.get_ds_memory_arm9_32
	api.mem.w.u[8] = drastic.set_ds_memory_arm9_8
	api.mem.w.s[8] = drastic.set_ds_memory_arm9_8
	api.mem.w.u[16] = drastic.set_ds_memory_arm9_16
	api.mem.w.s[16] = drastic.set_ds_memory_arm9_16
	api.mem.w.u[32] = drastic.set_ds_memory_arm9_32
	api.mem.w.s[32] = drastic.set_ds_memory_arm9_32
	api.joy.get.up 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_UP) ~= 0) end
	api.joy.get.down 	= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_DOWN) ~= 0) end
	api.joy.get.left 	= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_LEFT) ~= 0) end
	api.joy.get.right 	= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_RIGHT) ~= 0) end
	api.joy.get.a 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_A) ~= 0) end
	api.joy.get.b 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_B) ~= 0) end
	api.joy.get.x 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_X) ~= 0) end
	api.joy.get.y 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_Y) ~= 0) end
	api.joy.get.l 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_L) ~= 0) end
	api.joy.get.r 		= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_R) ~= 0) end
	api.joy.get.start 	= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_START) ~= 0) end
	api.joy.get.select 	= function () return (bit_and(drastic.get_buttons(), drastic.C.BUTTON_SELECT) ~= 0) end
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
function set_version()
	if api.mem.r.u[16](0x0200000E) == 0x333B then
		jp = false
		print("en")
	else
		jp = true
		print("jp")
	end
end

-- important addresses in memory
adr = {}
-- all JP are -400 from EN, unless marked, or the bottom several (attack data) which are -30
--  Could maybe just assume -400 unless specified
function init_adr()
	adr = {
		input = 0x04000130, -- readonly. 0x03FF by default, each input toggles off a certain bit
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
		x_palette = jp and 0x020DA9E2 or 0x020DE7C6, -- JP = EN - 3DE4
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
		final_hitbox_ptr_tracker_ptr = jp and 0x02108738 or 0x02108B38, -- jp guessed
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
controls = {'Y', 'R', 'B', 'L', 'X', 'A'}
function read_controls ()
	if api.mem.r.u[8](adr.control_type) == 0 then --type A
		controls = {'Y', 'R', 'B', 'L', 'X', 'A'}
	elseif api.mem.r.u[8](adr.control_type) == 1 then --type B
		controls = {'Y', 'X', 'B', 'A', 'L', 'R'}
	else --custom
		local button
		for i=1,6,1 do
			button = api.mem.r.u[16](adr.control_bindings + i*0x2)
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
function read_button (action)
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

function determine_quickcharge_equipped (n)
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
	return determine_quickcharge_equipped(math.floor(n/2))
end

--just used within other functions for determining needed charge times
function max_charge_frames(lvl) --parameter 1 for lvl 1 charge or 2 for lvl2
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

autofill_frame_count = 0
hxcap = 32
fxcap = 32
lxcap = 32
pxcap = 32
death_timer = -1
function autofill_energy (args)
	local timer_seconds = args.timer_seconds

	--record WE cap for each model since we can only see equipped's cap
	if api.mem.r.u[8](adr.model) == 3 then
		hxcap = api.mem.r.u[8](adr.current_model_WE_cap)*4;
	elseif api.mem.r.u[8](adr.model) == 4 then
		fxcap = api.mem.r.u[8](adr.current_model_WE_cap)*4;
	elseif api.mem.r.u[8](adr.model) == 5 then
		lxcap = api.mem.r.u[8](adr.current_model_WE_cap)*4;
	elseif api.mem.r.u[8](adr.model) == 6 then
		pxcap = api.mem.r.u[8](adr.current_model_WE_cap)*4;
	end
	
	if api.mem.r.u[8](adr.HX_WE) < 32 or api.mem.r.u[8](adr.FX_WE) < 32 or api.mem.r.u[8](adr.LX_WE) < 32 or api.mem.r.u[8](adr.PX_WE) < 32 then --if any of HX, FX, LX, or PX has less than 32 (so count isnt always going)
		if autofill_frame_count < timer_seconds*60 then --number of frames til energy point
			autofill_frame_count = autofill_frame_count + 1
		else --if each model's WE less than assumed cap and not currently equipped, add WE point
			if api.mem.r.u[8](adr.HX_WE) < hxcap then --HX
				api.mem.w.u[8](adr.HX_WE, api.mem.r.u[8](adr.HX_WE) + 1)
			end
			if api.mem.r.u[8](adr.FX_WE) < fxcap then --FX
				api.mem.w.u[8](adr.FX_WE, api.mem.r.u[8](adr.FX_WE) + 1)
			end
			if api.mem.r.u[8](adr.LX_WE) < lxcap then --LX
				api.mem.w.u[8](adr.LX_WE, api.mem.r.u[8](adr.LX_WE) + 1)
			end
			if api.mem.r.u[8](adr.PX_WE) < pxcap then --PX
				api.mem.w.u[8](adr.PX_WE, api.mem.r.u[8](adr.PX_WE) + 1)
			end
			autofill_frame_count = 0
		end
	end
	
	--if equipped model's WE is higher than its cap, reduce to cap
	if api.mem.r.u[8](adr.current_model_WE) > api.mem.r.u[8](adr.current_model_WE_cap)*4 then
		if api.mem.r.u[8](adr.model) == 3 then --if HX
			api.mem.w.u[8](adr.HX_WE, api.mem.r.u[8](adr.current_model_WE_cap)*4)
		end
		if api.mem.r.u[8](adr.model) == 4 then --if FX
			api.mem.w.u[8](adr.FX_WE, api.mem.r.u[8](adr.current_model_WE_cap)*4)
		end
		if api.mem.r.u[8](adr.model) == 5 then --if LX
			api.mem.w.u[8](adr.LX_WE, api.mem.r.u[8](adr.current_model_WE_cap)*4)
		end
		if api.mem.r.u[8](adr.model) == 6 then --if PX
			api.mem.w.u[8](adr.PX_WE, api.mem.r.u[8](adr.current_model_WE_cap)*4)
		end
	end
	
	--refill at transerver
	if api.mem.r.u[8](adr.current_room) == 70 and api.mem.r.u[8](adr.something_transerver) == 27 and (api.mem.r.u[8](adr.HX_WE) < hxcap or api.mem.r.u[8](adr.FX_WE) < fxcap or api.mem.r.u[8](adr.LX_WE) < lxcap or api.mem.r.u[8](adr.PX_WE) < pxcap) then
		api.mem.w.u[8](adr.HX_WE, hxcap)
		api.mem.w.u[8](adr.FX_WE, fxcap)
		api.mem.w.u[8](adr.LX_WE, lxcap)
		api.mem.w.u[8](adr.PX_WE, pxcap)
	end
	--refill upon death
	if api.mem.r.u[8](adr.grounded_state) == 10 and api.mem.r.u[8](adr.player_hp) == 0 and death_timer == -1 then
		death_timer = 1
	elseif api.mem.r.u[8](adr.grounded_state) == 10 and api.mem.r.u[8](adr.player_hp) == 0 and death_timer > 0 then
		death_timer = death_timer + 1
		if death_timer == 80 then
			api.mem.w.u[8](adr.HX_WE, hxcap)
			api.mem.w.u[8](adr.FX_WE, fxcap)
			api.mem.w.u[8](adr.LX_WE, lxcap)
			api.mem.w.u[8](adr.PX_WE, pxcap)
			death_timer = 0 --set to 0 so stop incrementing, then later will set to -1 for reset
		end
	elseif death_timer > -1 and api.mem.r.u[8](adr.grounded_state) ~= 10 and api.mem.r.u[8](adr.player_hp) ~= 0 then
		death_timer = -1
	end
	if death_timer ~= -1 then
	end
	--fill when acquiring/upgrading model
end

double_jumping = false
jump_pressed = false
double_jump_remaining = false
jump_override = false --don't attempt "doublejump" if actually on the ground/wall
function double_jump (args)
	local ox = args.ox
	local zx = args.zx
	local x = args.x
	if ox or zx or x then
		if (api.mem.r.u[8](adr.model) == 1 and x) 
		or (api.mem.r.u[8](adr.model) == 2 and zx) 
		or (api.mem.r.u[8](adr.model) == 7 and ox) 
		then
			-- track jump button presses
			if double_jump_remaining 
			and read_button("jump") 
			and (
				api.mem.r.u[8](adr.grounded_state) ~= 0 
				and api.mem.r.u[8](adr.grounded_state) ~= 2
			) then
				jump_pressed = true
			end
			-- don't try to doublejump if on the ground/wall
			if (
				api.mem.r.u[8](adr.grounded_state) == 0 
				or api.mem.r.u[8](adr.grounded_state) == 2
				or api.mem.r.u[8](adr.grounded_state) == 3
			) and read_button("jump") then
				jump_override = true
			end
			if not read_button("jump") then
				jump_override = false
			end
			-- allow double jump again after touching ground/wall
			if not double_jump_remaining 
			and (
				api.mem.r.u[8](adr.grounded_state) == 0 
				or api.mem.r.u[8](adr.grounded_state) == 2
			) then
				double_jump_remaining = true
			end
			if double_jump_remaining 
			and jump_pressed 
			and not jump_override 
			and api.mem.r.u[8](adr.grounded_state) == 1
			then
				if api.mem.r.u[8](adr.overdrive) == 65 or api.mem.r.u[8](adr.overdrive) == 67 then
					--if overdrived, do a higher jump
					api.mem.w.s[32](adr.y_vel, -1280)
				else
					api.mem.w.s[32](adr.y_vel, -1088)
				end
				double_jumping = true
				double_jump_remaining = false
				-- set "jumping" animation
				if api.mem.r.u[8](adr.action_id) == 6 or api.mem.r.u[8](adr.action_id) == 7 then
					api.mem.w.u[8](adr.anim_id, 17)
					api.mem.w.u[8](adr.anim_frame, 0)
					if api.mem.r.u[8](adr.model) == 7 then
						api.mem.w.u[8](adr.anim_frame_timer, 4)
					else
						-- skip duration of 1st jumping frame for X and ZX (it looks weird)
						api.mem.w.u[8](adr.anim_frame_timer, 1)
					end
				end
				--api.mem.w.u[32](adr.last_platform_y, 33827805) doesnt work :(
			end
			-- jump is active
			if double_jumping then
				if not read_button("jump") then
					-- stop rising if jump button is released
					api.mem.w.s[32](adr.y_vel, 64)
				end
				-- if beginning to fall
				if api.mem.r.s[32](adr.y_vel) >= 0 then
					-- set "falling" animation
					if api.mem.r.u[8](adr.action_id) == 6 or api.mem.r.u[8](adr.action_id) == 7 then
						api.mem.w.u[8](adr.anim_id, 18)
						api.mem.w.u[8](adr.anim_frame, 0)
						api.mem.w.u[8](adr.anim_frame_timer, 4)
					end
					double_jumping = false
				end
			end
			if jump_pressed then
				jump_pressed = false
			end
		else
			if double_jump_remaining == true then
				double_jump_remaining = false
			end
			if jump_override == true then
				jump_override = false
			end
		end
	end
end

--sorry this one's a horror show...... but, it works :P
ground_punch_frame_count = -1
ground_punch_jump_attack_cooldown = false
ground_punch_jump_landing_cooldown = false
ground_punch_animation_frame_count = -1
function fx_ground_breaker_jump ()
	if api.mem.r.u[8](adr.model) == 4 then
		if ground_punch_jump_attack_cooldown and not (api.mem.r.u[8](adr.action_id) == 76 or api.mem.r.u[8](adr.action_id) == 77) and ground_punch_frame_count == -1 then
			ground_punch_jump_attack_cooldown = false --attack must end
		end
		if ground_punch_jump_landing_cooldown and api.mem.r.u[8](adr.grounded_state) == 0 and ground_punch_frame_count == -1 then
			ground_punch_jump_landing_cooldown = false --must land before jumping again
		end
		--print(ground_punch_jump_attack_cooldown)
		--print(ground_punch_jump_landing_cooldown)
		--print("frame ".. ground_punch_frame_count)
		--print("anim ".. ground_punch_animation_frame_count)
		if (
			api.mem.r.u[8](adr.last_ability_id) == 62 
			or api.mem.r.u[8](adr.last_ability_id) == 63
		) and (
			api.mem.r.u[8](adr.action_id) >= 0x74 
			and api.mem.r.u[8](adr.action_id) <= 0x77
		) and ground_punch_frame_count == -1 
		and not ground_punch_jump_attack_cooldown 
		and not ground_punch_jump_landing_cooldown 
		and api.mem.r.u[8](adr.grounded_state) == 0 
		and ground_punch_animation_frame_count == -1 
		then
			ground_punch_animation_frame_count = 0
			ground_punch_jump_attack_cooldown = true
		end
		if ground_punch_animation_frame_count > -1 then
			if ground_punch_animation_frame_count < 30 then
				ground_punch_animation_frame_count = ground_punch_animation_frame_count + 1
			else
				ground_punch_animation_frame_count = -1
			end
		end
		if ground_punch_animation_frame_count > 8 and read_button("jump") and not ground_punch_jump_landing_cooldown then
			ground_punch_frame_count = 0
			ground_punch_jump_attack_cooldown = true
			ground_punch_jump_landing_cooldown = true
		end
		if ground_punch_frame_count > -1 then
				if ground_punch_frame_count < 30 then -- 19 + 8 frames
					if ground_punch_frame_count == 0 then --must force first movement :/
						api.mem.w.u[32](adr.y_pos, api.mem.r.u[32](adr.y_pos) - 256*18)
						api.mem.w.u[8](adr.last_ability_id + 1, 0) --end something with endlag timer
					end
					if ground_punch_frame_count < 2 then
						api.mem.w.s[32](adr.y_vel, -8 * 256)
					end
				ground_punch_frame_count = ground_punch_frame_count + 1
				else
					ground_punch_frame_count = -1
					api.mem.w.s[32](adr.y_vel, 0)
				end
		end
	else
		if ground_punch_frame_count ~= -1 then
			ground_punch_frame_count = -1
		end
		if ground_punch_jump_attack_cooldown then
			ground_punch_jump_attack_cooldown = false
		end
	end
end

fireball_frames = -1
fireball_slot = -1
fireball_start_x = 0
fireball_start_y = 0
fireball_direction = 0 -- 1 if right, -1 if left
downward_fireball_remaining = false
function fx_aerial_punch_jump ()
	if api.mem.r.u[8](adr.model) == 4 then
		-- track an aerial fireball, even if Down is not pressed
		if fireball_frames == -1 
		and downward_fireball_remaining 
		and (
			api.mem.r.u[8](adr.last_ability_id) == 58 --latest attack is/was left arm punch
			or api.mem.r.u[8](adr.last_ability_id) == 59 --latest attack is/was right arm punch
		) and (
			api.mem.r.u[8](adr.action_id) == 85 --right arm beginning aerial punch
			or api.mem.r.u[8](adr.action_id) == 87 --left arm beginning aerial punch
		) and (
			api.mem.r.u[8](adr.grounded_state) ~= 0 --not grounded
			and api.mem.r.u[8](adr.grounded_state) ~= 2 --not on a wall
		)
		then
			fireball_frames = 0
			downward_fireball_remaining = false
			--print("go")
		end
		-- allow double jump again only after touching the ground or a wall
		if not downward_fireball_remaining 
		and (
			api.mem.r.u[8](adr.grounded_state) == 0 --ground
			or api.mem.r.u[8](adr.grounded_state) == 2 --wall
		) then
			downward_fireball_remaining = true
		end
		--fireball & velocity manipulation
		if fireball_frames > -1 then
			--print(downward_fireball_frames)
			--the frame the fireball comes out; must be pressing Down for custom behavior
			if fireball_frames == 9 and api.joy.get.down() then
				-- look through all the attack slots to locate the newly-launched fireball
				for i=0,23,1 do
					--print(adr.final_attack_slot_attack_id - i*244 .. " " .. api.mem.r.u[8](adr.final_attack_slot_attack_id - i*244))
					if api.mem.r.u[8](adr.final_attack_slot_attack_id - i*244) == api.mem.r.u[8](adr.last_ability_id) 
					and api.mem.r.u[8](adr.final_attack_slot_attack_id - i*244 + 3) == 0x11 -- fireball, not punch
					then
						fireball_slot = i
						--print(downward_fireball_slot)
						fireball_direction = api.mem.r.s[16](adr.final_attack_slot_direction - fireball_slot*244)*2+1
						fireball_start_x = api.mem.r.u[32](adr.final_attack_slot_x - fireball_slot*244) - fireball_direction*256*30
						--print(api.mem.r.u[32](adr.final_attack_slot_x - downward_fireball_slot*244))
						--print(api.mem.r.s[16](adr.final_attack_slot_direction - downward_fireball_slot*244))
						--print(api.mem.r.s[16](adr.final_attack_slot_direction - downward_fireball_slot*244)*(-2)-1)
						fireball_start_y = api.mem.r.u[32](adr.final_attack_slot_y)
						break
					end
				end
				if fireball_slot == -1 then
					--fireball was not located; cancel the jump
					fireball_frames = -1
				else
					-- launch player upwards
					api.mem.w.s[32](adr.y_vel, -5 * 256)
				end
			end
			-- while the fireball is potentially active
			if fireball_slot > -1 and fireball_frames > 9 and fireball_frames <= 34
			and api.mem.r.u[8](adr.final_attack_slot_attack_id - fireball_slot*244) == 0x3A
			and api.mem.r.u[8](adr.final_attack_slot_attack_id + 3 - fireball_slot*244) == 0x11
			then
				-- ensure the fireball travels downward
				--print(api.mem.r.u[32](adr.final_attack_slot_y - downward_fireball_slot*244))
				api.mem.w.u[8](adr.final_attack_slot_angle - fireball_slot*244, 196)
				api.mem.w.u[32](adr.final_attack_slot_y - fireball_slot*244, 
					api.mem.r.u[32](adr.final_attack_slot_y - fireball_slot*244) 
					+ (api.mem.r.u[32](adr.final_attack_slot_x - fireball_slot*244) - fireball_start_x)
					* fireball_direction)
				api.mem.w.u[32](adr.final_attack_slot_x - fireball_slot*244, fireball_start_x)
			elseif fireball_frames > 34 then
				-- reset fireball info
				fireball_frames = -2
				fireball_slot = -1
			end
			fireball_frames = fireball_frames + 1
		end
		--jump

	else
		-- reset values when swapping models
		if fireball_frames ~= -1 then
			fireball_frames = -1
		end
		if downward_fireball_remaining == true then
			downward_fireball_remaining = false
		end
	end
end

groundbreaker_count = -1
function fx_groundbreaker_multihit ()
	if api.mem.r.u[8](adr.model) == 4 then
		if groundbreaker_count > -1 and groundbreaker_count < 8 then
			groundbreaker_count = groundbreaker_count + 1
		elseif groundbreaker_count >= 8 then
			groundbreaker_count = -1
		end
		if api.mem.r.u[8](adr.priority) == 32 and groundbreaker_count == -1 then
			api.mem.w.u[8](adr.priority, 31)
			groundbreaker_count = 0
		end
	end
end

fx_charging_left = false
fx_charging_right = false
function fx_groundbreaker_quickcharge ()
	if api.mem.r.u[8](adr.model) == 4 then
		if read_button("main") and not fx_charging_left then
			fx_charging_left = true
		end
		if read_button("sub") and not fx_charging_right then
			fx_charging_right = true
		end
		if fx_charging_left and not read_button("main") and api.mem.r.u[8](adr.main_charge) > max_charge_frames(1) and api.joy.get.down() then --if charge released at >40 and down held
			api.mem.w.u[8](adr.main_charge, 120) --instant charge for groundbreaker
			--api.mem.w.u[8](adr.FX_WE, api.mem.r.u[8](adr.FX_WE) + 2) --refund 2 energy for groundbreaker
		end
		if fx_charging_right and not read_button("sub") and api.mem.r.u[8](adr.sub_charge) > max_charge_frames(1) and api.joy.get.down() then --if charge released at >40 and down held
			api.mem.w.u[8](adr.sub_charge, 120) --instant charge for groundbreaker
			--api.mem.w.u[8](adr.FX_WE, api.mem.r.u[8](adr.FX_WE) + 2) --refund 2 energy for groundbreaker
		end
	end
end

lx_charging = false
function lx_dragon (args)
	local reduce_energy_cost = args.reduce_energy_cost
	if api.mem.r.u[8](adr.model) == 5 then --if LX
		if (read_button("main") or read_button("sub")) and not lx_charging then
			lx_charging = true
		end
		if lx_charging and not (read_button("main") or read_button("sub")) 
		and api.mem.r.u[8](adr.main_charge) > max_charge_frames(1)-1 
		and api.joy.get.up() 
		then --if charge released at >40 and up held
			api.mem.w.u[8](adr.main_charge, 120) --instant charge for dragon
			if reduce_energy_cost then
				api.mem.w.u[8](adr.LX_WE, api.mem.r.u[8](adr.LX_WE) + 2) --refund 2 energy for dragon
			end
		end
		if not read_button("main") and not read_button("sub") and lx_charging then
			lx_charging = false
		end
	end
end

function lx_speed_sled ()
	if api.mem.r.u[8](adr.model) == 5 then --if LX
		if api.mem.r.s[16](adr.lx_sled_1_vel) < 0 then
			api.mem.w.s[16](adr.lx_sled_1_vel, -920)
		elseif api.mem.r.s[16](adr.lx_sled_1_vel) > 0 then
			api.mem.w.s[16](adr.lx_sled_1_vel, 920)
		end
		if api.mem.r.s[16](adr.lx_sled_2_vel) < 0 then
			api.mem.w.s[16](adr.lx_sled_2_vel, -920)
		elseif api.mem.r.s[16](adr.lx_sled_2_vel) > 0 then
			api.mem.w.s[16](adr.lx_sled_2_vel, 920)
		end
		if api.mem.r.s[16](adr.lx_sled_3_vel) < 0 then
			api.mem.w.s[16](adr.lx_sled_3_vel, -920)
		elseif api.mem.r.s[16](adr.lx_sled_3_vel) > 0 then
			api.mem.w.s[16](adr.lx_sled_3_vel, 920)
		end
	end
end

lx_skullcrushing = 0
lx_skullcrush_slot = -1
-- LX's blade stays active while holding down after an aerial slash
function lx_skullcrush ()
	if api.mem.r.u[8](adr.model) == 5 then --if LX
		for i=0,23,1 do --find current slash
			if api.mem.r.u[8](adr.final_attack_slot_active_direction - i*244)%0x10 == 0xF 
			and api.mem.r.u[8](adr.final_attack_slot_attack_id - i*244) == 67 
			then 
				if lx_skullcrushing == 0 and 
				api.mem.r.u[8](adr.final_attack_slot_anim_frame - i*244) == 7 
				and api.joy.get.down() and api.mem.r.u[8](adr.grounded_state) == 1 
				then
					lx_skullcrushing = 1
					lx_skullcrush_slot = i
				end
			end
		end
		if lx_skullcrushing > 0 then
			api.mem.w.u[8](adr.final_attack_slot_anim_frame - lx_skullcrush_slot*244, 7) --freeze slash frame
			api.mem.w.u[8](adr.final_attack_slot_anim_frame+1 - lx_skullcrush_slot*244, 2) --fixes flashing
			if lx_skullcrushing == 1 and api.mem.r.u[8](adr.anim_frame) == 7 and api.mem.r.u[8](adr.anim_frame_timer) == 1 then
				lx_skullcrushing = 2
			elseif lx_skullcrushing == 2 then
				api.mem.w.u[8](adr.anim_frame_timer, 2) --freeze character sprite
				api.mem.w.u[32](adr.final_attack_slot_anim_something - lx_skullcrush_slot*244, adr.hb_lx_something) --hitbox
			end
			if not api.joy.get.down() or api.mem.r.u[8](adr.grounded_state) ~= 1 then
				lx_skullcrushing = 0
			end
		end
	elseif lx_skullcrushing ~= 0 then --just for robustness
		lx_skullcrushing = 0
	end
end

-- Swimming feels snappier and less floaty
function lx_remove_minimum_swim_distance()
	if api.mem.r.u[8](adr.grounded_state) == 4 then --swimming
		--general idea: immediately clamp velocity to 0 once deceleration begins
		local x_vel = api.mem.r.s[32](adr.x_vel)
		local y_vel = api.mem.r.s[32](adr.y_vel)
		-- if (x_vel ~= 0) then print(x_vel) end
		if ((x_vel > 0 and x_vel < 512)) then -- decelerating right
			api.mem.w.s[32](adr.x_vel, 0)
		elseif (x_vel < 0 and x_vel > -512) then --decelerating left
			api.mem.w.s[32](adr.x_vel, -1)
		end
		if ((y_vel > 0 and y_vel < 512)) then --decelerating down
			api.mem.w.s[32](adr.y_vel, 0)
		elseif (y_vel < 0 and y_vel > -512) then --decelerating up
			api.mem.w.s[32](adr.y_vel, -1)
		end
	end
end

swimdash_frames = 35
swimdash_ready = true
-- Swimdashes maintain speed better, and can be held indefinitely
function lx_improved_swimdash(args)
	local dash_speed = args.non_overdrive_speed
	local overdrive_speed = args.overdrive_speed
	local e_infinite_dash = args.enable_non_overdrive_infinite_dash
	local e_overdrive_infinite_dash = args.enable_overdrive_infinite_dash
	local decel_frames = args.num_deceleration_frames
		if api.mem.r.u[8](adr.model) == 5 then
		local is_swimdashing = api.mem.r.u[8](adr.anim_id) >= 6 and api.mem.r.u[8](adr.anim_id) <= 10
		if is_swimdashing then
			local is_overdrived = e_overdrive_infinite_dash and (api.mem.r.u[8](adr.overdrive) == 65 or api.mem.r.u[8](adr.overdrive) == 67)
			local dash_frames_remaining = api.mem.r.u[8](adr.dash_frames_remaining)
			-- handle dash speed
			if is_overdrived and overdrive_speed > 0 --enable constant dashspeed for overdrive
			and dash_frames_remaining < overdrive_speed --don't override the initial burst of speed
			and swimdash_frames > decel_frames --stop writing once we reach decel frames
			then
				api.mem.w.u[8](adr.dash_frames_remaining, overdrive_speed)
			elseif not is_overdrived and dash_speed > 0 --enable constant dashspeed for non-overdrive
			and dash_frames_remaining < dash_speed --don't override the initial burst of speed
			and swimdash_frames > decel_frames --stop writing once we reach decel frames
			then
				api.mem.w.u[8](adr.dash_frames_remaining, dash_speed)
			end
			-- count remaining frames if not infinite
			if (is_overdrived and not e_overdrive_infinite_dash) --we're overdrive but infinite overdrive dash is disabled
			or (not is_overdrived and not e_infinite_dash) --OR we're non-overdrive but infinite dash is disabled
			then
				--initialize our own swimdash frame counter
				if swimdash_ready then
					swimdash_frames = 35
					swimdash_ready = false
				end
				--decrement counter each frame
				swimdash_frames = swimdash_frames - 1
			end
		else
			swimdash_ready = true
			swimdash_frames = 35
		end
	end
end

--spin slash out of water by pressing attack + up [experimental]
function lx_spinslash()
	if api.mem.r.u[8](adr.model) == 5 then
		if (api.joy.get.r() or api.joy.get.y()) and api.joy.get.up() --attack + Up pressed
		--and api.mem.r.u[8](adr.last_ability_id, 67) --airslashed
		and api.mem.r.u[8](adr.grounded_state) == 1 --in air
		--and api.mem.r.u[8](adr.grounded_state) ~= 4 --not swimming
		then
			api.mem.w.u[8](adr.last_ability_id, 76) --set attack ID to swimslash
			--memory.writebyte(0x0214F848, 70)
		end
	end
end

continuous_overdrive = false
airdash_frames = -1
--HX can airdash continuously by consuming energy
function hx_infinite_airdash(args)
	local require_overdrive = args.require_overdrive
	local adjustment_rate = args.perpendicular_movement_speed
	local energy_rate = args.energy_consumption_rate
	if api.mem.r.u[8](adr.model) == 3 then
		if api.mem.r.u[8](adr.grounded_state) == 1 and ((require_overdrive and (api.mem.r.u[8](adr.overdrive) == 65 or api.mem.r.u[8](adr.overdrive) == 67) or not require_overdrive)) and continuous_overdrive == false then
			continuous_overdrive = true
		elseif continuous_overdrive == true and (api.mem.r.u[8](adr.grounded_state) == 1 or ((require_overdrive and (api.mem.r.u[8](adr.overdrive) == 65 or api.mem.r.u[8](adr.overdrive) == 67) or not require_overdrive))) then 
			continuous_overdrive = false --false if you land or if overdrive is disabled at any point in the air
		end
		if api.mem.r.u[8](adr.grounded_state) == 1 and ((require_overdrive and (api.mem.r.u[8](adr.overdrive) == 65 or api.mem.r.u[8](adr.overdrive) == 67) or not require_overdrive)) and (api.mem.r.u[8](adr.dash_frames_remaining-1) == 12 or api.mem.r.u[8](adr.dash_frames_remaining-1) == 20) and (energy_rate == 0 or api.mem.r.u[8](adr.HX_WE) > 0) and api.mem.r.u[8](adr.dash_frames_remaining) == 2 then
			if airdash_frames == -1 then
				if api.mem.r.u[8](adr.dash_frames_remaining-1) == 12 and api.mem.r.u[8](adr.dash_frames_remaining) == 27 then  --side airdash
					airdash_frames = 28 --start counter, will start taxing after normal dash length
				elseif api.mem.r.u[8](adr.dash_frames_remaining-1) == 20 and api.mem.r.u[8](adr.dash_frames_remaining) == 12 then  --up airdash
					airdash_frames = 13 --start counter, will start taxing after normal dash length
				end
			end
			api.mem.w.u[8](adr.dash_frames_remaining, 3)
			if adjustment_rate > 0 then
				if api.mem.r.u[8](adr.dash_frames_remaining-1) == 12 then --side airdash
					if api.joy.get.up() then
						api.mem.w.u[32](adr.y_pos, api.mem.r.u[32](adr.y_pos) - 256*adjustment_rate)
					elseif api.joy.get.down() then
						api.mem.w.u[32](adr.y_pos, api.mem.r.u[32](adr.y_pos) + 256*adjustment_rate)
					end
				elseif api.mem.r.u[8](adr.dash_frames_remaining-1) == 20 then --up airdash
					if api.joy.get.left() then
						api.mem.w.u[32](adr.x_pos, api.mem.r.u[32](adr.x_pos) - 256 - 256*adjustment_rate)
					elseif api.joy.get.right() then
						api.mem.w.u[32](adr.x_pos, api.mem.r.u[32](adr.x_pos) + 256 + 256*adjustment_rate)
					end
				end
			end
			airdash_frames = airdash_frames - 1
			if airdash_frames < 0 then
				if api.mem.r.u[8](adr.dash_frames_remaining-1) == 12 and airdash_frames%(10*energy_rate) == 0 then --use additional energy
					api.mem.w.u[8](adr.HX_WE, api.mem.r.u[8](adr.HX_WE) - 1)
				end
				if api.mem.r.u[8](adr.dash_frames_remaining-1) == 20 and airdash_frames%(6*energy_rate) == 0 then --even more for updash additional energy
					api.mem.w.u[8](adr.HX_WE, api.mem.r.u[8](adr.HX_WE) - 1)
				end
			end
		end
		if continuous_overdrive and api.mem.r.u[8](adr.dash_frames_remaining-1) == 4 then
			api.mem.w.u[8](adr.dash_frames_remaining-1, 0)
		end
	end
end

highjump_frame_count = -1
b_initial_press = 0 --0=not pressed, 1=initial press frame, 2=held down
--PX can jump to the ceiling, like X6's Shadow Armor
function px_highjump ()
	if api.mem.r.u[8](adr.model) == 6 then
		if b_initial_press > 0 and not read_button("jump") then
			b_initial_press = 0
		end
		if b_initial_press == 0 and read_button("jump") then
			b_initial_press = 1
		end
		if api.mem.r.u[8](adr.PX_WE) > 0 
		and api.mem.r.u[8](adr.grounded_state) == 0 
		and b_initial_press == 1 and api.joy.get.up() 
		and not api.joy.get.left() 
		and not api.joy.get.right() 
		then
			highjump_frame_count = 0
			api.mem.w.u[8](adr.PX_WE, api.mem.r.u[8](adr.PX_WE) - 1) --spend 1 energy
		end
		if highjump_frame_count > -1 then
			if highjump_frame_count < 16 then
				api.mem.w.s[32](adr.y_vel, -8 * 256)
				highjump_frame_count = highjump_frame_count + 1
			else
				highjump_frame_count = -1
				api.mem.w.s[32](adr.y_vel, 0)
			end
		end
		if b_initial_press == 1 then
			b_initial_press = 2
		end
	else
		if highjump_frame_count > -1 then
			highjump_frame_count = -1
		end
		if b_initial_press > 0 then
			b_initial_press = 0
		end
	end
end

-- Throw kunai straight forward in the air by pressing the subweapon button
function px_kunai_spread_control ()
	if api.mem.r.u[8](adr.model) == 6 then
		if api.mem.r.u[32](adr.px_kunai_angles) == 0x30201000 then
			if read_button("sub") then
				api.mem.w.u[32](adr.px_kunai_angles, 0)
			end
		elseif api.mem.r.u[32](adr.px_kunai_angles) == 0 then
			if read_button("main") then
				api.mem.w.u[32](adr.px_kunai_angles, 0x30201000)
			end
		end
	end
end

kunai_r_frames = -1
kunai_y_frames = -1
--this function exists in case the normal one is causing slowdowns (unused? can't remember where issues were happening)
function px_kunai_spread_control_ALTERNATE ()
	if api.mem.r.u[8](adr.model) == 6 then
		if read_button("sub") then
			if kunai_r_frames < 3 then
				kunai_r_frames = kunai_r_frames + 1
			end
		elseif kunai_r_frames > -1 then
			kunai_r_frames = -1
		end
		if read_button("main") then
			if kunai_y_frames < 3 then
				kunai_y_frames = kunai_y_frames + 1
			end
		elseif kunai_y_frames > -1 then
			kunai_y_frames = -1
		end
		if api.mem.r.u[8](adr.px_num_kunai_in_last) == 0 then
			if kunai_r_frames > -1 and kunai_r_frames < 3 then
				api.mem.w.u[32](adr.px_kunai_angles, 0)
				kunai_r_frames = 3 --so that this only happens for 1 frame
			elseif kunai_y_frames > -1 and kunai_y_frames < 3 then
				api.mem.w.u[32](adr.px_kunai_angles, 0x30201000)
				kunai_y_frames = 3
			end
		end
	end
end

px_jump_pressed_frames = -1
shuriken_jump_possible = false
shuriken_jump_need_land = false
shuriken_jump_need_new_shuriken = false
px_jump_override = false --prevent doublejumping if on the ground/wall
shuriken_jumping = false
shuriken_index = -1
post_shuriken_counter = -1
--PX can doublejump off of a thrown shuriken
function px_shuriken_jump ()
	if api.mem.r.u[8](adr.model) == 6 then
		-- track aerial jump button press, somewhat generally
		if not shuriken_jump_need_land 
		and read_button("jump") 
		and (
			api.mem.r.u[8](adr.grounded_state) ~= 0 
			and api.mem.r.u[8](adr.grounded_state) ~= 2
		) then
			-- we'll have a buffer period for the jump activation
			px_jump_pressed_frames = px_jump_pressed_frames + 1
		end
		-- touching ground/wall
		if (
			api.mem.r.u[8](adr.grounded_state) == 0 --ground
			or api.mem.r.u[8](adr.grounded_state) == 2 --wall
			or api.mem.r.u[8](adr.grounded_state) == 3 --?
		) then
			shuriken_jumping = false
			-- satisfy landing requirement for re-enabling doublejump
			shuriken_jump_need_land = false
			-- prevent "doublejump" getting activated when on the ground/wall
			px_jump_override = true
		end
		if not read_button("jump") then
			px_jump_override = false
		end
		if api.mem.r.u[8](adr.grounded_state) == 1 then --in the air
			if shuriken_index == -1 then
				-- check for shuriken existence
				for i=0,23,1 do --look through all attack slots
					if api.mem.r.u[8](adr.final_attack_slot_active_direction - i*244)%0x10 == 0xF 
					and api.mem.r.u[8](adr.final_attack_slot_active_direction-1 - i*244) == 0x0A
					then --PX attack ID, if shuriken
						shuriken_index = i
						--print("shuriken active")
					end
				end
			else -- shuriken exists
				if post_shuriken_counter == -1 and api.mem.r.u[8](adr.final_attack_slot_active_direction - shuriken_index*244)%0x10 == 0xA then
					-- shuriken has expired
					post_shuriken_counter = 0
				elseif post_shuriken_counter > -1 then
					--provide a few grace frames after the shuriken disappears
					post_shuriken_counter = post_shuriken_counter + 1
					if post_shuriken_counter > 3 then
						-- reset values
						shuriken_index = -1
						post_shuriken_counter = -1
						shuriken_jump_possible = false
						shuriken_jump_need_new_shuriken = false
					end
				else
					-- shuriken is active
					local player_x = api.mem.r.u[32](adr.x_pos)
					local player_y = api.mem.r.u[32](adr.y_pos)
					local shuriken_x = api.mem.r.u[32](adr.final_attack_slot_x - shuriken_index*244)
					local shuriken_y = api.mem.r.u[32](adr.final_attack_slot_y - shuriken_index*244)
					-- print("p:"..player_x.." "..player_y.." s:"..shuriken_x.." "..shuriken_y)
					if player_x > shuriken_x - 16*512 --player within shuriken's left bound
					and player_x < shuriken_x + 16*512  --player within shuriken's right bound
					and player_y > shuriken_y - 9*512  --player within shuriken's upper bound
					and player_y < shuriken_y + 13*512  --player within shuriken's lower bound
					then
						-- player & shuriken hitboxes are touching/within range
						shuriken_jump_possible = true
					else
						shuriken_jump_possible = false
					end
				end
			end
		end
		-- all conditions to initialize the actual jump:
		if not shuriken_jump_need_land
		and not shuriken_jump_need_new_shuriken
		and shuriken_jump_possible 
		-- and px_jump_pressed 
		and px_jump_pressed_frames < 5
		and not px_jump_override 
		and api.mem.r.u[8](adr.grounded_state) == 1 
		and read_button("jump")
		then
			shuriken_jump_possible = false
			shuriken_jump_need_land = true
			shuriken_jump_need_new_shuriken = true
			shuriken_jumping = true
			-- launch upward
			-- api.mem.w.s[32](adr.y_vel, -5 * 256)
			api.mem.w.s[32](adr.y_vel, -1216)
			-- set "jumping" animation
			if api.mem.r.u[8](adr.action_id) == 6 or api.mem.r.u[8](adr.action_id) == 7 then
				api.mem.w.u[8](adr.anim_id, 17)
				api.mem.w.u[8](adr.anim_frame, 0)
				api.mem.w.u[8](adr.anim_frame_timer, 4)
			end
			--api.mem.w.u[32](adr.last_platform_y, 33827805) doesnt work :(
		end
		-- jump is active
		if shuriken_jumping then
			-- if jump button released early
			if not read_button("jump") then
				-- cancel upward momentum
				api.mem.w.s[32](adr.y_vel, 64)
			end
			-- if beginning to fall
			if api.mem.r.s[32](adr.y_vel) >= 0 then
				-- set "falling" animation
				if api.mem.r.u[8](adr.action_id) == 6 or api.mem.r.u[8](adr.action_id) == 7 then
					api.mem.w.u[8](adr.anim_id, 18)
					api.mem.w.u[8](adr.anim_frame, 0)
					api.mem.w.u[8](adr.anim_frame_timer, 4)
				end
				shuriken_jumping = false
			end
		end
		-- reset after the buffer window
		if px_jump_pressed_frames > 5 then
			px_jump_pressed_frames = -1
		end
	else
		-- reset values when swapping model
		shuriken_jumping = false
		shuriken_jump_possible = false
		px_jump_override = false
	end
end

function model_switch ()
	if api.joy.get.select() then
		if api.joy.get.l() then
			api.mem.w.u[8](adr.model, 1) --X
		elseif api.joy.get.r() then
			api.mem.w.u[8](adr.model, 2) --ZX
		elseif api.joy.get.up() then
			api.mem.w.u[8](adr.model, 3) --HX
		elseif api.joy.get.down() then
			api.mem.w.u[8](adr.model, 4) --FX
		elseif api.joy.get.left() then
			api.mem.w.u[8](adr.model, 5) --LX
		elseif api.joy.get.right() then
			api.mem.w.u[8](adr.model, 6) --PX
		elseif api.joy.get.a() then
			api.mem.w.u[8](adr.model, 7) --OX
		end
	end
end

pal_x_armor = {{0x06D6018E, 0x63FF1FDE},
			   {0x00390010, 0x5F1F1D1F},
			   {0x6E4A4944, 0x7FDC7F53}}
--pal_x_green = {0x16E10DA0, 0x6BF82BC8}
--pal_x_lavender = {0x69F14509, 0x7FDE7ED7}

pal_chargeshot = {{0x7BDE, 0x7FF9, 0x5F85, 0x52C0, false, 0x5FFF, 0x3BF6, 0x3F80, 0x7F20, 0x6240, 0x3EDF, 0x51DF},
				  {false, 0x33DC, 0x1FAF, false, false, 0x43FF, false, false, 0x3360, 0x36A0, 0x13FF, 0x03BD},
				  {false, 0x2B7F, 0x1A1F, false, false, 0x37FF, false, false, 0x111E, 0x0018, 0x273F, 0x1E5F},
				  {false, 0x7FF9, 0x7FB3, false, false, 0x7FF9, false, false, 0x7F25, 0x6E20, 0x7F4F, 0x6ECA}}

adr.chargeshot_palettes = {0x021CF982, 0x021CFF32, 0x021D0492, 0x021D09F2, 0x021D0F52}

a_pressed_status = 0
element_equipped = 0 --0 none, 1 elec, 2 fire, 3 ice
function x_element_switch (x, z)
	if (x and api.mem.r.u[8](adr.definite_model) == 1) or (z and api.mem.r.u[8](adr.definite_model) == 2) then --X/ZX
		--record default chargeshot colors
		--[[
		for i=1,13,1 do
			pal_chargeshot[1][i] = api.mem.r.u[16](adr.chargeshot_palettes[1]+(i-1)*2)
		end
		]]
		--A instant press status (to avoid switching every frame while pressed)
		if read_button("overdrive") and a_pressed_status == 0 then
			a_pressed_status = 1
		elseif read_button("overdrive") and a_pressed_status == 1 then
			a_pressed_status = 2
		elseif not read_button("overdrive") then
			a_pressed_status = 0
		end
		--Switch element
		if a_pressed_status == 1 then
			if element_equipped < 3 then
				element_equipped = element_equipped + 1
			else
				element_equipped = 0
			end
		end
		--Use element if attack used
		if api.mem.r.u[8](adr.priority) == 3 or api.mem.r.u[8](adr.priority) == 224 then --priority of blue shot with pink orbits or charge saber
			api.mem.w.u[8](0x02150C9F, element_equipped * 16) -- set element
		end
		if element_equipped == 0 then
			--gui.text(6,-94, "N")
			--reset armor colors
			if api.mem.r.u[32](adr.current_model_palette + 0xB) ~= 0x7FFF7B7A then
				for i=1,15,1 do
					api.mem.w.u[16](adr.current_model_palette + (i-1)*2, api.mem.r.u[16](adr.x_palette + (i-1)*2))
				end
			end
			--reset fake overdrive
			if api.mem.r.u[8](adr.overdrive) == 67 then 
				api.mem.w.u[8](adr.overdrive, 66)
			end
		else --if element
			--set palette
			if api.mem.r.u[32](adr.current_model_palette + 0xB) ~= pal_x_armor[element_equipped][1] then
				api.mem.w.u[32](adr.current_model_palette + 0xB, pal_x_armor[element_equipped][1])
				api.mem.w.u[32](adr.current_model_palette + 0xE, pal_x_armor[element_equipped][2])
			end
			--apply fake overdrive
			if api.mem.r.u[8](adr.overdrive) == 64 or api.mem.r.u[8](adr.overdrive) == 66 then 
				api.mem.w.u[8](adr.overdrive, 67)
			end
			--element doesnt get first shot of doubleshot, for balance :) need to find way to let you release button to shoot it though :(
			--[[
			if api.mem.r.u[16](adr.main_charge) == 0x6060 then
				api.mem.w.u[16](adr.main_charge, 0x6000) 
			end
			]]
			--find fired charge shots
			for i=0,23,1 do
				if api.mem.r.u[8](adr.final_attack_slot_active_direction - i*244)%0x10 == 0xF then 
					if api.mem.r.u[8](adr.final_attack_slot_attack_id-1 - i*244) >= 2 then
						api.mem.w.u[8](adr.final_attack_slot_overdrive - i*244, 0x0F)
						api.mem.w.u[8](adr.final_attack_slot_overdrive+1 - i*244, 0x0A)
						api.mem.w.u[8](adr.final_attack_slot_element - i*244, element_equipped)
						api.mem.w.u[8](adr.final_attack_slot_element - i*244+1, 0x02)
					else
						api.mem.w.u[8](adr.final_attack_slot_element - i*244, 0) --remove element from slot when using other attacks
					end
				end
			end
		end
		--change charge shot color
		if api.mem.r.u[16](adr.chargeshot_palettes[1] + 2) ~= pal_chargeshot[element_equipped+1][2] then
			for i,x in ipairs(adr.chargeshot_palettes) do
				for j,y in ipairs(pal_chargeshot[element_equipped+1]) do
					if y then
						api.mem.w.u[16](x+(j-1)*2, y)
					end
				end
			end
		end
	end
end
--elemental chips todo:
--script to determine slots containing charge shot
--script to apply colors (all 5 palettes; check out main though?)
-- how to make elemental:
-- -apply overdrive
-- -set attack overdrive value to 0F
-- -set element
-- ?-set element+1 to 01



--- Aesthetic changes (enable in main function below) ---

dash_count = 26
dash_color = 6175 --red 6 steps backwards toward magenta
dash_delta = -1024
prev_dash_value = 0
function rainbow_dash()
	-- weird address storing various current/recent movement data...
	-- local dash_active = bit_and(1, api.mem.r.u[8](adr.movement_info)) == 1 or api.mem.r.u[8](adr.dash_type) > 0

	local paused = api.mem.r.u[8](adr.is_paused) == 192 or api.mem.r.u[8](adr.is_paused) == 64
	if not paused then
		for i=0,14,1 do
			api.mem.w.u[16](adr.dash_pal_start + i*2, dash_color)
		end
		
		dash_color = dash_color + dash_delta
		
		if dash_count < 31 then
			dash_count = dash_count + 1
		else
			dash_count = 1
			if dash_delta == 32 then
				dash_delta = -1
			elseif dash_delta == -1 then
				dash_delta = 1024
			elseif dash_delta == 1024 then
				dash_delta = -32
			elseif dash_delta == -32 then
				dash_delta = 1
			elseif dash_delta == 1 then
				dash_delta = -1024
			elseif dash_delta == -1024 then
				dash_delta = 32
			end
		end
	end
end

function spinspinspin ()
	for i=0,19,1 do
		rando = math.random(0,255)
		api.mem.w.u[8](adr.final_attack_slot_angle - i*244, rando)
	end
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
		local rect_center_x = cam_offset_x + 128*0x100
		local rect_center_y = cam_offset_y + 96*0x100
		local topleft_x = rect_center_x - (width/2)
		local topleft_y = rect_center_y - (height/2)
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
		next_frame_hitboxes[#next_frame_hitboxes+1] = {
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
prev_frame_hitboxes = {}
enable_hitbox_viewer = false
enable_hitbox_viewer_pressed = false
function display_hitboxes()
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



--MAIN
started = false
function mods()
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

	autofill_energy({timer_seconds = 3}) --Autofill 1 energy to all models every 3 seconds
	--autofill energy arguments: (seconds between each automatic unit refill)

	--Gives double jump to OX, ZX, X (set booleans to toggle for each)
	double_jump({
		ox = true,
		zx = true,
		x = true
	})
	--[planned: toggle ability to doublejump during a dash jump for each model]

	fx_ground_breaker_jump() --Hold Jump as FX while using ground breaker to do a recoil rod-style super jump
	fx_aerial_punch_jump() --Can shoot fireball downward in the air for a vertical boost
	fx_groundbreaker_multihit() --Groundbreaker now hits multiple times on bosses
	fx_groundbreaker_quickcharge() --Groundbreaker available at lv1 (green) charge

	lx_dragon({reduce_energy_cost = true}) --Reduces the charge time and energy cost of ice dragon
	lx_speed_sled() --ice sled instantly accelerates to max speed
	lx_skullcrush() --Hold down during an airslash to extend the final hitbox
	lx_remove_minimum_swim_distance() --Gives LX tighter control while swimming
	lx_improved_swimdash({
		-- speed can range from 1 to 34; or set to 0 to disable custom behavior
		non_overdrive_speed = 34,
		overdrive_speed = 34,
		-- enable infinite swimdash by holding the dash button
		enable_non_overdrive_infinite_dash = false,
		enable_overdrive_infinite_dash = true,
		num_deceleration_frames = 0 -- only matters if either of the infinite swimdash options is disabled
	}) --remove deceleration while swimdashing, and enable infinite swimdashing
	lx_spinslash() --Hold up while inputting an airslash to do a spinslash [experimental]

	hx_infinite_airdash({
		require_overdrive = true,
		perpendicular_movement_speed = 1, -- 0=none, 1=slow, 2=fast
		energy_consumption_rate = 2 -- 0=none, 1=slow, 2=fast
	}) --airdash infinitely while in overdrive, and adjust your position perpendicular to your dash

	px_highjump() --Hold up as PX and press B to do a MMX6 Shadow Armor-style highjump
	px_kunai_spread_control() --Press sub weapon button as PX to throw kunai straight forward, press main weapon button for classic spread
	px_shuriken_jump() --Doublejump off your shuriken

	--x_element_switch(false, false) --Press Overdrive button to switch between elements applied to X's charge attacks (like MMZ chips)

	model_switch() -- press Select + another button to instantly switch model
	-- L: X, R: ZX, Up: HX, Down: FX, Left: LX, Right: PX, A: OX
	
	rainbow_dash() --a shifting rainbow trail
	--spinspinspin() --unleash the beyblade

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
