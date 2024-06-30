ENT.Type = "anim"

ENT.PrintName = "Trampoline"
ENT.Author = "void pointer"
ENT.Contact = "cfc.gg/discord"
ENT.Purpose = "Bouncy circle"
ENT.Instructions = "Use with care."
ENT.Spawnable = true
ENT.IsTrampoline = true
ENT.MAXIMUM_RADIUS = 60 ^ 2
ENT.HEIGHT_TO_BOUNCY_SURFACE = 29.5

CreateConVar( "sbox_maxcfc_trampoline", 5, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Maximum amount of trampolines owned by a player at once." )

function ENT:Initialize()
    self:SetModel( "models/cfc/cfc_trampoline.mdl" )
    if SERVER then
        self:SetTrigger( true )
        self:PhysicsInit( SOLID_VPHYSICS )
    end

    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveCollide( MOVECOLLIDE_FLY_CUSTOM )

    self:PhysWake()
    local phys = self:GetPhysicsObject()

    if not IsValid( phys ) then return end
    phys:SetMass( 250 )
end

local flags = FCVAR_ARCHIVE + FCVAR_PROTECTED + FCVAR_REPLICATED
local MIN_SPEED = CreateConVar( "cfc_trampoline_min_speed", 180, flags, "Minimum speed required to bounce off of a trampoline", 0, 50000 )
local BOUNCE_MIN = CreateConVar( "cfc_trampoline_bounce_min", 320, flags, "Minimum resulting speed of a bounce", 0, 50000 )
local BOUNCE_MULT = CreateConVar( "cfc_trampoline_bounce_mult", 0.8, flags, "How much a player will be bounced up relative to their falling velocity", 0, 50000 )
local BOUNCE_MULT_JUMPING = CreateConVar( "cfc_trampoline_bounce_mult_jumping", 1.2, flags, "How much a player will be bounced up relative to their falling velocity while holding their jump button", 0, 50000 )
local BOUNCE_MAX = CreateConVar( "cfc_trampoline_bounce_max", 1500, flags, "Maximum resulting speed of a bounce", 0, 50000 )
local HEIGHT_TO_BOUNCY_SURFACE = ENT.HEIGHT_TO_BOUNCY_SURFACE
local MAXIMUM_RADIUS = ENT.MAXIMUM_RADIUS

local SOUND_FILTER = SERVER and RecipientFilter() or nil
function ENT.bouncePlayer( trampoline, ply, plyPhys, speed )
    if not IsValid( ply ) then return end
    if not IsValid( plyPhys ) and not CLIENT then return end

    local isHoldingJump = ply:KeyDown( IN_JUMP )
    local bounceMult = isHoldingJump and BOUNCE_MULT_JUMPING:GetFloat() or BOUNCE_MULT:GetFloat()
    local bounceSpeed = math.min( speed * bounceMult, BOUNCE_MAX:GetFloat() )
    local up = trampoline:GetUp()
    local appliedVelocity = up * bounceSpeed

    local isUnfrozen = SERVER and trampoline:GetPhysicsObject():IsMotionEnabled() or false
    if isUnfrozen then
        -- hacky solution to bounce players when the trampoline is unfrozen
        -- Raphael: This breaks prediction. Is this really needed?
        plyPhys:SetPos( plyPhys:GetPos() + up * 5 )
    end

    if SERVER then
    	SOUND_FILTER:RemoveAllPlayers()
    	SOUND_FILTER:AddPAS( trampoline:GetPos() + trampoline:GetUp() * HEIGHT_TO_BOUNCY_SURFACE )
    	SOUND_FILTER:RemovePlayer( ply ) -- Sound is played clientside for the jumping player.

    	net.Start( "CFC_BouncyCircle_PlayBounceSound" )
    	net.WriteEntity( trampoline )
    	net.Send( SOUND_FILTER )
    else
    	if IsFirstTimePredicted() then
    		trampoline:bounceSound()
    	end
    end

    return appliedVelocity
end

local HEIGHT_TO_BOUNCY_SURFACE = ENT.HEIGHT_TO_BOUNCY_SURFACE
local MAXIMUM_RADIUS = ENT.MAXIMUM_RADIUS
function ENT:isBouncyPart( position )
    if not IsValid( self ) then return end

    local trampolinePos = self:GetPos()
    local trampolineUp = self:GetUp()
    local bouncyOrigin = trampolinePos + trampolineUp * HEIGHT_TO_BOUNCY_SURFACE

    local dist = position:DistToSqr( bouncyOrigin )
    if dist > MAXIMUM_RADIUS then return false end -- Too far from center of the bouncy part

    local bouncyToPos = ( position - bouncyOrigin ):GetNormalized()

    local dot = bouncyToPos:Dot( trampolineUp )
    if dot <= 0 then return false end -- Hitting from below

    return true
end

local CL_LAST_TICK
local CL_LAST_VELOCITY
local CL_DELAY = 0
local CL_NEWCOMMAND = false
local LAST_VELOCITY = {}
local JUMP_VEC = Vector( 0, 0, 0 )
local ent_class = "cfc_trampoline"
hook.Add( "SetupMove", "Trampoline_Prediction", function( ply, mv, cmd ) -- BUG: The ViewPunch is not predicted!
	local ent = ply:GetGroundEntity()
	local plyIndex = ply:EntIndex()
	if ent ~= NULL then
		if ent:GetClass() == ent_class and ent:isBouncyPart( ply:GetPos() ) then
			local lastVel = LAST_VELOCITY[ plyIndex ]
			if not lastVel then
				lastVel = mv:GetVelocity()
			end

			if CLIENT then
				CL_NEWCOMMAND = cmd:TickCount() ~= CL_LAST_TICK
				if ( not CL_NEWCOMMAND and not IsFirstTimePredicted() ) and CL_LAST_VELOCITY then -- We already calculated it :D
					mv:SetVelocity( CL_LAST_VELOCITY )
					return
				end
			end

			local newVel
			local trampolineDown = -ent:GetUp()
			local upSpeed = lastVel:Dot( trampolineDown )
			if cmd:KeyDown( IN_JUMP ) then -- This will change the behavior since when we now Jump we directly get boosted. Before that, we had to land on it again to get the boost.
				local jumpPower = ply:GetJumpPower()
				local jump = jumpPower > upSpeed
				newVel = mv:GetVelocity() + ent:bouncePlayer( ply, ply:GetPhysicsObject(), math.max( jump and jumpPower or upSpeed, BOUNCE_MIN:GetFloat() ), true )
			else
				if upSpeed > MIN_SPEED:GetFloat() then
					newVel = mv:GetVelocity() + ent:bouncePlayer( ply, ply:GetPhysicsObject(), math.max( upSpeed, BOUNCE_MIN:GetFloat() ), false )
				end
			end

			if newVel then
				mv:SetVelocity( newVel )
			end

			LAST_VELOCITY[ plyIndex ] = newVel

			if CLIENT then
				CL_LAST_VELOCITY = newVel
			end
		end

		if CLIENT then
			CL_LAST_TICK = cmd:TickCount()
		end

		LAST_VELOCITY[ plyIndex ] = nil
	else
		LAST_VELOCITY[ plyIndex ] = mv:GetVelocity()
	end
end )