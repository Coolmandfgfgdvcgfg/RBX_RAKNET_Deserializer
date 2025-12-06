local Deser = {}

-- helpers

local Game = game
local GetDescendants = Game.GetDescendants
local GetDebugId = Instance.new("Part").GetDebugId
local Infinite = math.huge

local function GetInstanceById(idStr)
    local list = GetDescendants(Game)
    for i = 1, #list do
        local d = list[i]
        if GetDebugId(d, Infinite) == idStr then
            return d
        end
    end
end

local function readu16_le(buf, offset)
    local lo = buffer.readu8(buf, offset)
    local hi = buffer.readu8(buf, offset + 1)
    return lo + hi * 256
end

-- constants

Deser.TouchType = {
    Begin   = 1,
    End     = 0,
    Unknown = -1,
}

-- Touch packet 0x86

function Deser.decodeTouch86(pkt)
    local len = buffer.len(pkt)
    if len < 2 then return nil, "too short" end
    if buffer.readu8(pkt, 0) ~= 0x86 then return nil, "not 0x86" end

    local subId = buffer.readu8(pkt, 1)
    local entrySize = 11
    local payload = len - 2
    if payload < 0 then return nil, "bad length" end

    local count = math.floor(payload / entrySize)

    local result = {
        id = 0x86,
        subId = subId,
        targets = {},
    }

    local targetMap = {}

    for i = 0, count - 1 do
        local base = 2 + i * entrySize

        local targetId  = readu16_le(pkt, base + 0)
        local unkA      = buffer.readu8(pkt, base + 2)
        local unkB      = buffer.readu8(pkt, base + 3)
        local unkC      = buffer.readu8(pkt, base + 4)
        local toucherId = readu16_le(pkt, base + 5)
        local unkD      = buffer.readu8(pkt, base + 7)
        local flagA     = buffer.readu8(pkt, base + 8)
        local flagB     = buffer.readu8(pkt, base + 9)
        local flagC     = buffer.readu8(pkt, base + 10)

        local touchType
        if flagA == 0 and flagB == 0 and flagC == 0 then
            touchType = Deser.TouchType.Begin
        elseif flagA == 0 and flagB == 3 and flagC == 0 then
            touchType = Deser.TouchType.End
        else
            touchType = Deser.TouchType.Unknown
        end

        local t = targetMap[targetId]
        if not t then
            t = {
                targetId = targetId,
                target = GetInstanceById(tostring(targetId)),
                touches = {},
            }
            targetMap[targetId] = t
            table.insert(result.targets, t)
        end

        table.insert(t.touches, {
            type   = touchType,
            partId = toucherId,
            part   = GetInstanceById(tostring(toucherId)),
            flags  = { flagA, flagB, flagC },
            unk    = { unkA, unkB, unkC, unkD },
            index  = i + 1,
        })
    end

    return result
end

return Deser
