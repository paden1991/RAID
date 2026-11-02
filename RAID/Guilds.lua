local _,R=...
R.guildTTL=86400;R.guildLimit=3000
local function realmName()
    return ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ''):gsub('%s',''):lower()
end
function R:NameKey(name)
    if not self:IsPlain(name) or type(name)~='string' or name=='' then return end
    local short,realm=name:match('^([^%-]+)%-(.+)$')
    if not short then short=name;realm=realmName() end
    if realm=='' then return end
    return short:lower()..'-'..realm:gsub('%s',''):lower()
end
function R:PruneGuilds()
    local now=time();local all={}
    for key,v in pairs(self.db.members) do
        if type(v)~='table' or type(v.at)~='number' or v.at>now+60 or now-v.at>self.guildTTL or
            not self:GuildMatches(v.guild) or type(v.name)~='string' then self.db.members[key]=nil
        else all[#all+1]={key=key,at=v.at} end
    end
    table.sort(all,function(a,b)if a.at~=b.at then return a.at>b.at end;return a.key<b.key end)
    for i=self.guildLimit+1,#all do self.db.members[all[i].key]=nil end
    self.byGUID={}
    for key,v in pairs(self.db.members) do if type(v.guid)=='string' then self.byGUID[v.guid]=key end end
end
function R:Remember(name,guild,guid,source)
    if not self:IsPlain(name) or not self:IsPlain(guild) or not self:IsPlain(guid) then return end
    local key=self:NameKey(name)
    if not key or type(guild)~='string' then return end
    if guid and UnitGUID and guid==UnitGUID('player') then return end
    local alias=guid and self.byGUID[guid]
    if alias and alias~=key then self.db.members[alias]=nil;self.byGUID[guid]=nil end
    local old=self.db.members[key]
    guid=guid or old and old.guid
    if old and old.guid then self.byGUID[old.guid]=nil end
    if not self:GuildMatches(guild) then self.db.members[key]=nil;return end
    self.db.members[key]={name=name,guild=guild,guid=guid,at=time(),source=source}
    if guid then self.byGUID[guid]=key end
    self.additions=(self.additions or 0)+1
    if self.additions>=100 then self.additions=0;self:PruneGuilds() end
end
function R:ObserveUnit(unit)
    if not self:IsPlain(unit) or type(unit)~='string' or not UnitIsPlayer or not GetGuildInfo then return end
    local player=UnitIsPlayer(unit)
    if not self:IsPlain(player) or not player then return end
    local name,realm
    if UnitFullName then name,realm=UnitFullName(unit) elseif UnitName then name,realm=UnitName(unit) end
    if not self:IsPlain(name) or not self:IsPlain(realm) or not name then return end
    if realm and realm~='' then name=name..'-'..realm end
    local guild=GetGuildInfo(unit)
    -- Nil can mean the client hasn't received guild data yet, not "no guild".
    if self:IsPlain(guild) and guild then self:Remember(name,guild,UnitGUID and UnitGUID(unit),'Nearby / group') end
end
function R:ObserveGroup()
    for _,unit in ipairs({'target','focus','mouseover'}) do self:ObserveUnit(unit) end
    for i=1,4 do self:ObserveUnit('party'..i) end
    for i=1,40 do self:ObserveUnit('raid'..i) end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _,plate in ipairs(C_NamePlate.GetNamePlates() or {}) do self:ObserveUnit(plate.namePlateUnitToken) end
    end
end
function R:IsGuildBlocked(name,guid)
    if not self:IsPlain(name) or not self:IsPlain(guid) then return false end
    if guid and UnitGUID and guid==UnitGUID('player') then return false end
    local key=self:NameKey(name);local v=key and self.db.members[key]
    if guid and self.byGUID[guid] then key=self.byGUID[guid];v=self.db.members[key] end
    if not v and guid and UnitTokenFromGUID then
        local unit=UnitTokenFromGUID(guid)
        if unit then self:ObserveUnit(unit);key=self.byGUID[guid] or key;v=key and self.db.members[key] end
    end
    if not v then return false end
    if time()-v.at>self.guildTTL or v.at>time()+60 then
        self.db.members[key]=nil;if v.guid then self.byGUID[v.guid]=nil end;return false
    end
    -- A renamed/recreated character must not inherit another GUID's block.
    return (not guid or not v.guid or guid==v.guid) and self:GuildMatches(v.guild)
end
function R:ReadWho()
    local count=C_FriendList and C_FriendList.GetNumWhoResults or GetNumWhoResults
    local get=C_FriendList and C_FriendList.GetWhoInfo or GetWhoInfo
    if not count or not get then return end
    -- Assign first: this API returns zero values before ready, or (shown, total).
    -- Passing count() directly to tonumber treats total as a numeric base.
    local shown=count()
    local n=tonumber(shown) or 0
    for i=1,math.min(n,100) do
        local name,guild=get(i)
        if type(name)=='table' then guild=name.fullGuildName or name.guild;name=name.fullName or name.name end
        if type(name)=='string' and type(guild)=='string' then self:Remember(name,guild,nil,'Who results') end
    end
end
function R:ScanGuilds()
    -- A local refresh, not a server Who query. Guild matching runs automatically.
    self:PruneGuilds();self:ObserveGroup()
    self.status='Nearby guilds refreshed. Matching uppercase OLYMPUS automatically.'
    self:RefreshPanel();return true
end
function R:MatchingGuildCount()
    local names={};local n=0;local now=time()
    for _,v in pairs(self.db.members)do
        if now-v.at<=self.guildTTL and v.at<=now+60 and self:GuildMatches(v.guild) and not names[v.guild] then
            names[v.guild]=true;n=n+1
        end
    end
    return n
end
function R:ClearGuilds()
    self.db.members={};self.byGUID={};self.status='Guild cache cleared; new observations will refill it.'
end
function R:GuildCount()
    local n=0;for _,v in pairs(self.db.members) do if time()-v.at<=self.guildTTL then n=n+1 end end;return n
end
