resource.AddWorkshop( "3114940538" )

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )
util.AddNetworkString( "CFC_BouncyCircle_PlayBounceSound" )

local IN_JUMP = IN_JUMP
local IsValid = IsValid

-- this is so we get slightly above the trampoline
-- because the GetPos returns a position near the ground, we get
-- the point [self:GetUp()] * [HEIGHT_TO_BOUNCY_SURFACE] from it
local HEIGHT_TO_BOUNCY_SURFACE = ENT.HEIGHT_TO_BOUNCY_SURFACE

-- maximum radius the trampoline will allow
-- this is used in DistToSqr
local MAXIMUM_RADIUS = ENT.MAXIMUM_RADIUS

local flags = FCVAR_ARCHIVE + FCVAR_PROTECTED

local MIN_SPEED = GetConVar( "cfc_trampoline_min_speed" )
local BOUNCE_MIN = GetConVar( "cfc_trampoline_bounce_min" )
local BOUNCE_MAX = GetConVar( "cfc_trampoline_bounce_max" )
local BOUNCE_RECOIL = CreateConVar( "cfc_trampoline_bounce_mult_recoil", 0.4, flags, "The force multiplier applied in the opposite direction when bouncing on an unfrozen trampoline", 0, 50000 )

local function bounceOther( trampoline, entPhys, speed )
    if not IsValid( trampoline ) then return end
    if not IsValid( entPhys ) then return end

    local up = trampoline:GetUp()

    local bounceSpeed = math.min( speed, BOUNCE_MAX:GetFloat() )
    local appliedVelocity = up * bounceSpeed

    entPhys:ApplyForceCenter( appliedVelocity * entPhys:GetMass() )
    return appliedVelocity
end

function ENT:Bounce( ent, theirPhys, speed )
    if not IsValid( self ) then return end
    if not IsValid( ent ) then return end
    if not IsValid( theirPhys ) then return end

    local appliedVelocity = vector_origin
    if ent:IsPlayer() then
        appliedVelocity = self:bouncePlayer( ent, theirPhys, speed )
    elseif not ent:IsNPC() then
        appliedVelocity = bounceOther( theirPhys, speed )
    end

    net.Start( "CFC_BouncyCircle_PlayBounceSound" )
    net.WriteEntity( self )
    net.SendPAS( self:GetPos() + self:GetUp() * HEIGHT_TO_BOUNCY_SURFACE )

    return appliedVelocity
end

local function MakeTrampoline( ply, Data )
    local validPly = IsValid( ply )
    if validPly and not ply:CheckLimit( "cfc_trampoline" ) then return nil end

    local ent = ents.Create( "cfc_trampoline" )
    if not ent:IsValid() then return end
    duplicator.DoGeneric( ent, Data )
    ent:Spawn()
    ent:Activate()

    local physObj = ent:GetPhysicsObject()
    physObj:EnableMotion( false )

    duplicator.DoGenericPhysics( ent, ply, Data )

    if validPly then
        ply:AddCount( "cfc_trampoline", ent )
        ply:AddCleanup( "cfc_trampoline", ent )
    end

    return ent
end

duplicator.RegisterEntityClass( "cfc_trampoline", MakeTrampoline, "Data" )

function ENT:SpawnFunction( ply, tr )
    if not tr.Hit then return end

    return MakeTrampoline( ply, { Pos = tr.HitPos } )
end

local collisionVels = {}

function ENT:PhysicsCollide( colData )
    local ent = colData.HitEntity
    if not IsValid( ent ) then return end
    if collisionVels[ent] then return end -- Only store vel if this is part of a new bounce
    if ent:IsPlayer() then return end -- Players are handled differently
    if not self:isBouncyPart( colData.HitPos ) then return end

    collisionVels[ent] = colData.TheirOldVelocity
end

function ENT:StartTouch( ent )
    if ent:IsWorld() or ent:IsPlayer() then return end
    if ent.Trampoline_Bouncing then return end

    local entVel = collisionVels[ent] or ent:GetVelocity()
    collisionVels[ent] = nil -- Remove from velocity cache

    local tr = self:GetTouchTrace()
    local pos = tr.HitPos

    local shouldBounce = self:isBouncyPart( pos )
    if not shouldBounce then return end

    -- Just a safety measure. Makes sure Bounce can't be called until EndTouch is called again
    ent.Trampoline_Bouncing = true
    local theirPhys = ent:GetPhysicsObject()

    -- negate because velocity will be the opposite direction
    local trampolineDown = -self:GetUp()
    local upSpeed = entVel:Dot( trampolineDown )
    if upSpeed < MIN_SPEED:GetFloat() then return end

    local appliedVelocity = self:Bounce( ent, theirPhys, math.max( upSpeed, BOUNCE_MIN:GetFloat() ) )

    local myPhys = self:GetPhysicsObject()

    if myPhys:IsMotionEnabled() then
        myPhys:ApplyForceCenter( -appliedVelocity * BOUNCE_RECOIL:GetFloat() * theirPhys:GetMass() )
    end
end

function ENT:EndTouch( e )
    e.Trampoline_Bouncing = nil
end

local world = game.GetWorld()
hook.Add( "GetFallDamage", "Trampoline_FallDamage", function( ply )
    if not IsValid( ply ) then return end

    local groundEnt = ply:GetGroundEntity()
    if not groundEnt then return end
    if groundEnt == world then return end
    if not groundEnt.IsTrampoline then return end

    local isBouncy = groundEnt:isBouncyPart( ply:GetPos() )
    if not isBouncy then return end

    return 0
end )
