local addon,R=...
_G.RAIDFilter=R
R.events={'CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_CHANNEL','CHAT_MSG_GUILD','CHAT_MSG_OFFICER',
    'CHAT_MSG_WHISPER','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER','CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER',
    'CHAT_MSG_RAID_WARNING','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER',
    'CHAT_MSG_BATTLEGROUND','CHAT_MSG_BATTLEGROUND_LEADER','CHAT_MSG_EMOTE','CHAT_MSG_TEXT_EMOTE',
    'CHAT_MSG_BN_WHISPER','CHAT_MSG_BN_CONVERSATION'}
function R:Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffd100RAID:|r '..text) end
end
function R:Init()
    RAIDDB=type(RAIDDB)=='table' and RAIDDB or {}
    self.db=RAIDDB;local db=self.db
    db.settings=type(db.settings)=='table' and db.settings or {}
    for _,key in ipairs({'enabled','guild','words','asmongold','asmon','asmonLayer','han','cyrillic'}) do
        if type(db.settings[key])~='boolean' then db.settings[key]=true end
    end
    self:InitChannels()
    self:InitKeywords()
    db.members=type(db.members)=='table' and db.members or {}
    self.stats={guild=0,words=0,han=0,cyrillic=0};self.recent={};self.recentOrder={};self.byGUID={}
    self:PruneGuilds()
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    self.filter=function(_,event,msg,author,...)
        if not R.db.settings.enabled then return false end
        -- Fail open before inspecting any restricted chat payload.
        if not R:IsPlain(msg) or not R:IsPlain(author) then return false end
        for i=1,select('#',...) do
            if not R:IsPlain(select(i,...)) then return false end
        end
        if not R:ChannelEnabled(event,select(7,...),select(6,...)) then return false end
        local lineID,guid=select(9,...),select(10,...)
        local reason
        if R.db.settings.guild and not event:find('CHAT_MSG_BN_',1,true) and R:IsGuildBlocked(author,guid) then reason='guild' end
        reason=reason or R:TextReason(msg)
        if not reason then return false end
        -- The same event is filtered once for each chat window. Count it once.
        local key=event..':'..tostring(author)..':'..(type(lineID)=='number' and lineID>0 and tostring(lineID) or tostring(msg)..':'..math.floor(GetTime()/2))
        if not R.recent[key] then
            R.stats[reason]=R.stats[reason]+1;R.recent[key]=true;R.recentOrder[#R.recentOrder+1]=key
            if #R.recentOrder>256 then R.recent[table.remove(R.recentOrder,1)]=nil end
        end
        return true
    end
    self.registered=0
    if add then for _,event in ipairs(self.events) do
        if pcall(add,event,self.filter) then self.registered=self.registered+1 end
    end end
    if self.registered==0 then self:Print('Chat filter API unavailable on this client. Filtering is inactive.') end
    self:InitMinimap();self:ObserveGroup()
end
local frame=CreateFrame('Frame');R.frame=frame
for _,event in ipairs({'ADDON_LOADED','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED',
    'UPDATE_MOUSEOVER_UNIT','NAME_PLATE_UNIT_ADDED','GROUP_ROSTER_UPDATE','UNIT_NAME_UPDATE','UNIT_GUILD_UPDATE','WHO_LIST_UPDATE','CHANNEL_UI_UPDATE','CHANNEL_ROSTER_UPDATE'}) do
    pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript('OnEvent',function(_,event,arg)
    if event=='ADDON_LOADED' then if arg==addon and not R.db then R:Init() end;return end
    if R.db and (event=='CHANNEL_UI_UPDATE' or event=='CHANNEL_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD')then
        R:RefreshChannels();if R.panel and R.panel:IsShown() then R:RefreshPanel() end
    end
    if R.db and event=='PLAYER_ENTERING_WORLD' then R:CreateMinimapButton();R:PositionMinimapButton()end
    if not R.db or not R.db.settings.enabled or not R.db.settings.guild then return end
    if event=='WHO_LIST_UPDATE' then R:ReadWho()
    elseif event=='PLAYER_ENTERING_WORLD' or event=='GROUP_ROSTER_UPDATE' then R:ObserveGroup()
    elseif event=='PLAYER_TARGET_CHANGED' then R:ObserveUnit('target')
    elseif event=='PLAYER_FOCUS_CHANGED' then R:ObserveUnit('focus')
    elseif event=='UPDATE_MOUSEOVER_UNIT' then R:ObserveUnit('mouseover')
    else R:ObserveUnit(arg) end
end)
SLASH_RAIDFILTER1='/raidfilter';SLASH_RAIDFILTER2='/rf'
SlashCmdList.RAIDFILTER=function(msg)
    if not R.db then return end
    msg=(msg or ''):lower():match('^%s*(.-)%s*$')
    if msg=='on' or msg=='off' then R:SetFilteringEnabled(msg=='on');R:Print(msg=='on' and 'Filtering enabled.' or 'Filtering paused.')
    elseif msg=='minimap hide' then R:SetMinimapShown(false);R:Print('Minimap button hidden. Restore with /rf minimap show.')
    elseif msg=='minimap' or msg=='minimap show' then R:SetMinimapShown(true)
    elseif msg=='minimap reset' then R.db.minimap.angle=195;R:SetMinimapShown(true);R:PositionMinimapButton()
    elseif msg=='scan' or msg=='refresh' then R:ScanGuilds()
    elseif msg=='clear' then R:ClearGuilds();R:Print('Confirmed guild cache cleared.')
    elseif msg=='channels' then R:ShowOptions('channels')
    elseif msg=='keywords' then R:ShowOptions('keywords')
    elseif msg=='options' or msg=='rules' then R:ShowOptions('rules')
    else R:TogglePanel() end
end
