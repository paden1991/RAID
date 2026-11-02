local _,R=...
R.version='0.2.3-beta'
-- Restricted client values must not be compared, parsed, logged or cached.
function R:IsPlain(value)
    return not issecretvalue or not issecretvalue(value)
end
-- Inspect displayed text, not hidden hyperlink IDs, colors or texture paths.
function R:VisibleText(text)
    if not self:IsPlain(text) or type(text)~='string' then return '' end
    text=text:gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t',''):gsub('|A.-|a','')
    return (text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''))
end
function R:GuildMatches(guild)
    return self:IsPlain(guild) and type(guild)=='string' and guild:find('OLYMPUS',1,true)~=nil
end
function R:KeywordMatches(text)
    text=text:lower()
    -- Asmon also covers the requested phrase "asmon layer". Word boundaries
    -- avoid unrelated words such as "jasmine" or "plasmon".
    local s=self.db.settings
    return s.asmongold and text:find('%f[%w_]asmongold%f[^%w_]')~=nil or
        s.asmon and text:find('%f[%w_]asmon%f[^%w_]')~=nil or
        s.asmonLayer and text:find('%f[%w_]asmon%s+layer%f[^%w_]')~=nil or self:CustomKeywordMatches(text)
end
local function continuation(b)return b and b>=128 and b<=191 end
function R:ScriptReason(text,han,cyrillic)
    local i,n=1,#text
    while i<=n do
        local a,b,c,d=text:byte(i,i+3);local cp,step=a,1
        if a>=194 and a<=223 and continuation(b) then cp=(a-192)*64+b-128;step=2
        elseif a>=224 and a<=239 and continuation(b) and continuation(c) and
            (a~=224 or b>=160) and (a~=237 or b<160) then
            cp=(a-224)*4096+(b-128)*64+c-128;step=3
        elseif a>=240 and a<=244 and continuation(b) and continuation(c) and continuation(d) and
            (a~=240 or b>=144) and (a~=244 or b<=143) then
            cp=(a-240)*262144+(b-128)*4096+(c-128)*64+d-128;step=4
        end
        if han and (cp>=0x3400 and cp<=0x4DBF or cp>=0x4E00 and cp<=0x9FFF or
            cp>=0xF900 and cp<=0xFAFF or cp>=0x20000 and cp<=0x2EE5F or
            cp>=0x2F800 and cp<=0x2FA1F or cp>=0x30000 and cp<=0x323AF or
            cp>=0x3100 and cp<=0x312F or cp>=0x31A0 and cp<=0x31BF) then return 'han' end
        if cyrillic and (cp>=0x0400 and cp<=0x052F or cp>=0x1C80 and cp<=0x1C8F or
            cp>=0x2DE0 and cp<=0x2DFF or cp>=0xA640 and cp<=0xA69F or
            cp>=0x1E030 and cp<=0x1E08F) then return 'cyrillic' end
        i=i+step
    end
end
function R:TextReason(text)
    local s=self.db.settings;text=self:VisibleText(text)
    if s.words and self:KeywordMatches(text) then return 'words' end
    return self:ScriptReason(text,s.han,s.cyrillic)
end
