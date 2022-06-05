local material_flags = {
	[0x1] = "MATERIAL_VAR_DEBUG",
	[0x2] = "MATERIAL_VAR_NO_DEBUG_OVERRIDE",
	[0x4] = "MATERIAL_VAR_NO_DRAW",
	[0x8] = "MATERIAL_VAR_USE_IN_FILLRATE_MODE",
	[0x10] = "MATERIAL_VAR_VERTEXCOLOR",
	[0x20] = "MATERIAL_VAR_VERTEXALPHA",
	[0x40] = "MATERIAL_VAR_SELFILLUM",
	[0x80] = "MATERIAL_VAR_ADDITIVE",
	[0x100] = "MATERIAL_VAR_ALPHATEST",
	[0x200] = "MATERIAL_VAR_MULTIPASS",
	[0x400] = "MATERIAL_VAR_ZNEARER",
	[0x800] = "MATERIAL_VAR_MODEL",
	[0x1000] = "MATERIAL_VAR_FLAT",
	[0x2000] = "MATERIAL_VAR_NOCULL",
	[0x4000] = "MATERIAL_VAR_NOFOG",
	[0x8000] = "MATERIAL_VAR_IGNOREZ",
	[0x10000] = "MATERIAL_VAR_DECAL",
	[0x20000] = "MATERIAL_VAR_ENVMAPSPHERE",
	[0x40000] = "MATERIAL_VAR_NOALPHAMOD",
	[0x80000] = "MATERIAL_VAR_ENVMAPCAMERASPACE",
	[0x100000] = "MATERIAL_VAR_BASEALPHAENVMAPMASK",
	[0x200000] = "MATERIAL_VAR_TRANSLUCENT",
	[0x400000] = "MATERIAL_VAR_NORMALMAPALPHAENVMAPMASK",
	[0x800000] = "MATERIAL_VAR_NEEDS_SOFTWARE_SKINNING",
	[0x1000000] = "MATERIAL_VAR_OPAQUETEXTURE",
	[0x2000000] = "MATERIAL_VAR_ENVMAPMODE",
	[0x4000000] = "MATERIAL_VAR_SUPPRESS_DECALS",
	[0x8000000] = "MATERIAL_VAR_HALFLAMBERT",
	[0x10000000] = "MATERIAL_VAR_WIREFRAME",
	[0x20000000] = "MATERIAL_VAR_ALLOWALPHATOCOVERAGE",
	[0x40000000] = "MATERIAL_VAR_IGNORE_ALPHA_MODULATION"
}

local cvar_enabled = CreateConVar("sp_allowspray", "1", FCVAR_ARCHIVE, "Allow players to spraying a logo decal")
local cvar_animated = CreateConVar("sp_allowanimated", "1", FCVAR_ARCHIVE, "Allow players to use animated spray")

AccessorFunc(FindMetaTable"Player", "b_sprayValidated", "SprayValidated", FORCE_BOOL)

local flag_whitelist = {
	["MATERIAL_VAR_MULTIPASS"] = true,
	["MATERIAL_VAR_NOCULL"] = true,
	["MATERIAL_VAR_ALPHATEST"] = true,
	["MATERIAL_VAR_OPAQUETEXTURE"] = true,
	["MATERIAL_VAR_NO_DRAW"] = true,
	["MATERIAL_VAR_USE_IN_FILLRATE_MODE"] = true
}

hook.Add("PlayerSpray", "SprayPlus_DiscardInvalid", function(ply)
	if not cvar_enabled:GetBool() then return true end
	if ply:GetSprayValidated() then return end
	return true
end)

local function FlagsIsLegal(fl)
	if cvars.Bool"developer" then
		for flag, name in pairs(material_flags) do
			if bit.band(fl, flag) == flag then print(name) end
		end
	end
	for flag, name in pairs(material_flags) do
		if bit.band(fl, flag) == flag then 
			if not flag_whitelist[name] then return false end
		end
	end
	return true
end

local inited = {}
gameevent.Listen"OnRequestFullUpdate"
hook.Add("OnRequestFullUpdate", "SprayPlus_RunValidation", function(t)
	if not cvar_enabled:GetBool() then return end

	if inited[t.userid] then return end
	inited[t.userid] = true
	
	local ply = Player(t.userid)
	
	if not IsValid(ply) then return end
	
	local crc = ply:GetPlayerInfo().customfiles[1]
	
	if crc == "00000000" then
		ply:ChatPrint"[Spray+] You don't have a spray or spray file is invalid"
		return
	end
	
	local fpath = "download/user_custom/" .. crc:sub(1, 2) .. "/" .. crc .. ".dat"
	if not file.Exists(fpath, "GAME") then
		ply:ChatPrint"[Spray+] Your spray cannot be found in the server files."
		return
	end
	
	ply:ChatPrint(Format("[Spray+] Your spray was found in the server files (0x%s), validating...", crc))
	
	local fread = file.Open(fpath, "rb", "GAME")
	if fread:Read(4) ~= "VTF\0" then
		fread:Close()
		ply:ChatPrint"[Spray+] Your spray isn't a VTF file?"
		return
	end
	fread:Skip(12) -- 8 version[2] + 4 headerSize
	local width = fread:ReadUShort()
	local height = fread:ReadUShort()
	local flags = fread:ReadULong()
	local frames = fread:ReadUShort()
	fread:Close()
	
	ply:ChatPrint(Format("[Spray+] Spray size: %ix%i", width, height))
	
	if frames > 1 then
		if not cvar_animated:GetBool() then
			ply:ChatPrint"[Spray+] Animated sprays are disabled on this server, please choose some other."
			return
		end
		ply:ChatPrint(Format("[Spray+] Wow, your spray is animated and have %i frames!", frames))
	end
	
	if FlagsIsLegal(flags) then
		ply:SetSprayValidated(true)
		ply:ChatPrint"[Spray+] Your spray successfully validated, you can use it."
	else
		ply:ChatPrint"[Spray+] Your spray failed validation, please choose some other."
	end
end)
