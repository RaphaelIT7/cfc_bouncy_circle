return {
    groupName = "CFC Trampoline",
    cases = {
        {
            name = "Should create entity config convars",
            func = function()
                expect( ConVarExists( "cfc_trampoline_min_speed" ) ).to.beTrue()
                expect( GetConVar( "cfc_trampoline_min_speed" ):GetFloat() ).to.equal( 320 )
            end
        }
    }
}
