include( "shared.lua" )

function ENT:Draw()
    self:DrawModel()
end

local BOUNCE_SFX_VOLUME = CreateClientConVar( "cfc_trampoline_volume", 1, true, false, "Volume for the trampoline", 0, 1 )
function ENT:bounceSound()
	self:EmitSound( "cfc/cfc_trampoline/cfc_trampoline_bounce.ogg", 75, 100, BOUNCE_SFX_VOLUME:GetFloat() )
end

net.Receive( "CFC_BouncyCircle_PlayBounceSound", function()
    local ent = net.ReadEntity()
    if not IsValid( ent ) then return end

    ent:bounceSound()
end )
