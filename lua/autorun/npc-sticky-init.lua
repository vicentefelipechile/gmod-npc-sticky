--[[----------------------------------------------------------------------------
                                   NPC Sticky
----------------------------------------------------------------------------]]--

--[[------------------------------------
                  Hooks
------------------------------------]]--

local ENABLED = CreateConVar("npc_sticky_enabled", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "Enable or disable the NPC Sticky script.")

--[[
    Este script hace que los NPCs se "peguen" a las físicas de los objetos (props) en movimiento sobre los que están parados.
    Cuando el objeto se detiene, el NPC puede moverse libremente.
]]

-- Un umbral para considerar que un objeto está en movimiento. Ajusta este valor si es necesario.
local MOVEMENT_THRESHOLD_SQ = 10 -- Usamos el valor al cuadrado para evitar usar Sqrt() que es más lento.

hook.Add("Think", "NpcStickyToMovingProps", function()
    -- Si el script está desactivado, nos aseguramos de despegar cualquier NPC que haya quedado pegado.
    if not ENABLED:GetBool() then
        for _, npc in ipairs(ents.FindByClass("npc_*")) do
            if not ( npc:IsNPC() and npc:Alive() ) then continue end
            if npc.WasStuck then
                local parent = npc:GetParent()
                if IsValid(parent) then
                    npc:SetParent(nil)
                    npc:SetCollisionGroup(npc.OriginalCollisionGroup or COLLISION_GROUP_NPC)
                    npc:SetMoveType(npc.OriginalMoveType or MOVETYPE_STEP)
                end
                npc.WasStuck = nil
                npc.OriginalCollisionGroup = nil
                npc.OriginalMoveType = nil
            end
        end
        return
    end

    for _, npc in ipairs(ents.FindByClass("npc_*")) do
        if not ( npc:IsNPC() and npc:Alive() ) then continue end

        local parent = npc:GetParent()

        if npc.WasStuck then
            -- El NPC fue pegado por este script. Verificamos su estado.
            if IsValid(parent) and not parent:IsPlayer() then
                -- El padre es válido, verificamos si dejó de moverse o de estar congelado.
                local phys = parent:GetPhysicsObject()
                local isFrozen = IsValid(phys) and not phys:IsMotionEnabled()
                local isMoving = parent:GetVelocity():LengthSqr() > MOVEMENT_THRESHOLD_SQ
                if not isMoving and not isFrozen then
                    -- Dejó de moverse y no está congelado, así que lo despegamos.
                    npc:SetParent(nil)
                    npc:SetCollisionGroup(npc.OriginalCollisionGroup or COLLISION_GROUP_NPC)
                    npc:SetMoveType(npc.OriginalMoveType or MOVETYPE_STEP)
                    npc.WasStuck = nil
                    npc.OriginalCollisionGroup = nil
                    npc.OriginalMoveType = nil
                end
            -- Si sigue moviéndose o está congelado, no hacemos nada. Lo dejamos pegado.
            else
                -- El padre ya no es válido o es un jugador. Despegamos el NPC para limpiar el estado.
                if IsValid(parent) then npc:SetParent(nil) end -- Si estaba pegado a un jugador.
                npc:SetCollisionGroup(npc.OriginalCollisionGroup or COLLISION_GROUP_NPC)
                npc:SetMoveType(npc.OriginalMoveType or MOVETYPE_STEP)
                npc.WasStuck = nil
                npc.OriginalCollisionGroup = nil
                npc.OriginalMoveType = nil
            end
        else
            -- El NPC no está pegado. Verificamos si debería estarlo.
            -- No lo pegamos si ya está emparentado a otra cosa (para no interferir con otros scripts).
            if IsValid(parent) then continue end

            local groundEntity = npc:GetGroundEntity()
            if IsValid(groundEntity) and not groundEntity:IsWorld() then
                local class = groundEntity:GetClass()
                if string.match(class, "prop_") or string.match(class, "func_") then
                    local phys = groundEntity:GetPhysicsObject()
                    local isFrozen = IsValid(phys) and not phys:IsMotionEnabled()
                    local isMoving = groundEntity:GetVelocity():LengthSqr() > MOVEMENT_THRESHOLD_SQ
                    if isMoving or isFrozen then
                        -- El objeto se está moviendo o está congelado, lo pegamos.
                        npc.WasStuck = true
                        npc.OriginalCollisionGroup = npc:GetCollisionGroup()
                        npc.OriginalMoveType = npc:GetMoveType()

                        npc:SetParent(groundEntity)
                        npc:SetMoveType(MOVETYPE_NONE)
                        npc:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                    end
                end
            end
        end
    end
end)



--[[------------------------------------
                  Menu
------------------------------------]]--

if CLIENT then
    local function PoblateOptionsPanel(pnl)
        pnl:Help(language.GetPhrase("spawnmenu.utilities.npcsticky.options_desc"))

        -- Keybinds
        pnl:CheckBox(language.GetPhrase("spawnmenu.utilities.npcsticky.enable"), "npc_sticky_enabled")
    end

    hook.Add("AddToolMenuCategories", "NPC_Sticky:Options", function()
        spawnmenu.AddToolCategory("Utilities", "npcsticky", "#spawnmenu.utilities.npcsticky")
    end)

    hook.Add("PopulateToolMenu", "NPC_Sticky:Options", function()
        spawnmenu.AddToolMenuOption("Utilities", "npcsticky", "npcsticky_options", "#spawnmenu.utilities.npcsticky.options", "", "", PoblateOptionsPanel)
    end)
end