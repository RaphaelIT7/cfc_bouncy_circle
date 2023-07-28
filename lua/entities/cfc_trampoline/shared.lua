ENT.Type = "anim"

ENT.PrintName = "Trampoline"
ENT.Author = "void pointer"
ENT.Contact = "cfc.gg/discord"
ENT.Purpose = "Bouncy circle"
ENT.Instructions = "Use with care."
ENT.Spawnable = true
ENT.IsTrampoline = true

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
