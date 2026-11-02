local _,R=...
local function text(parent,value,x,y,width,style)
    local f=parent:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlight')
    f:SetPoint('TOPLEFT',x,y);f:SetWidth(width);f:SetJustifyH('LEFT');f:SetText(value);return f
end
local function button(parent,label,x,y,width,action)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,24)
    b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',action);return b
end
local function check(parent,label,x,y,width,action)
    local b=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate');b:SetSize(26,26);b:SetPoint('TOPLEFT',x,y)
    b.label=text(parent,label,x+32,y-5,width,'GameFontNormal');b:SetScript('OnClick',action);return b
end
function R:RefreshPanel()
    self:EnsureMinimapSettings();self:UpdateMinimapButton()
    if not self.panel then return end
    local f=self.panel;local s=self.db.settings
    if f.minimapCheck then f.minimapCheck:SetChecked(not self.db.minimap.hide)end
    for key,b in pairs(f.checks) do b:SetChecked(s[key]) end
    for _,key in ipairs({'asmongold','asmon','asmonLayer'})do f.checks[key]:SetEnabled(s.words)end
    for key,b in pairs(f.channelChecks) do b:SetChecked(s.channels[key]) end
    local active=0;for _,row in ipairs(self.channelTypes)do if s.channels[row[1]] then active=active+1 end end
    f.summary:SetText((s.enabled and self.registered>0 and active>0 and '|cff85df80Filtering active|r' or '|cffffc060Filtering paused / unavailable|r')..'  |  '..active..' / '..#self.channelTypes..' chat types  |  '..self:MatchingGuildCount()..' matching guild names observed')
    f.counts:SetText(string.format('Hidden this session: %d guild   /   %d keywords   /   %d Han   /   %d Cyrillic',self.stats.guild,self.stats.words,self.stats.han,self.stats.cyrillic))
    f.status:SetText(self.status or 'Automatic guild matching: nearby players, targets, mouseover and groups.')
    local rows=self:ChannelRows();local offset=math.min(self.channelOffset or 0,math.max(0,math.floor((#rows-1)/8)*8));self.channelOffset=offset
    for i,b in ipairs(f.publicChecks)do
        local row=rows[offset+i];b.channel=row
        b:SetShown(row~=nil);b.label:SetShown(row~=nil)
        if row then
            b.label:SetText(row.name..(row.joined and '' or ' (not joined)'))
            b:SetChecked(s.publicChannels[row.key]~=false);b:SetEnabled(s.channels.public)
        end
    end
    f.channelPage:SetText(#rows==0 and 'No joined or saved channels' or (offset+1)..'-'..math.min(offset+8,#rows)..' of '..#rows)
    f.channelPrev:SetEnabled(offset>0);f.channelNext:SetEnabled(offset+8<#rows)
    self:RefreshKeywords()
    local tab=self.optionsTab or 'rules'
    for key,page in pairs(f.pages)do page:SetShown(tab==key);f.tabs[key]:SetEnabled(tab~=key)end
end
function R:SetOptionsTab(tab)
    self.optionsTab=(tab=='channels' or tab=='keywords')and tab or 'rules'
    if self.panel then self.panel.keywordInput:ClearFocus()end
    self:RefreshChannels();self:RefreshPanel()
end
function R:RefreshKeywords()
    local f=self.panel;local s=self.db.settings;local rows=s.customKeywords
    local offset=math.min(self.keywordOffset or 0,math.max(0,math.floor((#rows-1)/8)*8));self.keywordOffset=offset
    for i,row in ipairs(f.keywordRows)do
        local entry=rows[offset+i];row.index=entry and offset+i or nil
        row.check:SetShown(entry~=nil);row.check.label:SetShown(entry~=nil);row.mode:SetShown(entry~=nil);row.remove:SetShown(entry~=nil)
        if entry then
            row.check.label:SetText((entry.text:gsub('|','||')));row.check:SetChecked(entry.enabled)
            row.mode:SetText(entry.mode=='contains'and 'Contains' or 'Whole words')
        end
    end
    f.keywordPage:SetText(#rows==0 and 'No custom keywords yet' or (offset+1)..'-'..math.min(offset+8,#rows)..' of '..#rows..' / '..self.keywordLimit)
    f.keywordPrev:SetEnabled(offset>0);f.keywordNext:SetEnabled(offset+8<#rows)
    f.keywordNotice:SetText(self.keywordMessage or 'Enter one word or phrase, then press Add or Enter.')
    f.keywordState:SetText(not s.enabled and 'RAID is paused. Your list is saved.'or not s.words and 'Keyword filtering is off on Rules. Your list is saved.'or 'Active on your enabled channels. Uncheck an entry to pause it.')
end
function R:AddKeywordFromInput()
    local f=self.panel;local ok,message,index=self:AddKeyword(f.keywordInput:GetText(),self.keywordMode)
    self.keywordMessage=message;if index then self.keywordOffset=math.floor((index-1)/8)*8 end
    if ok then f.keywordInput:SetText('')end
    self:RefreshPanel();f.keywordInput:SetFocus()
end
function R:ShowOptions(tab)
    if not self.panel then self:TogglePanel()else self.panel:Show()end
    self:SetOptionsTab(tab)
end
function R:TogglePanel()
    if self.panel then self.panel:SetShown(not self.panel:IsShown());self:RefreshChannels();self:RefreshPanel();return end
    local f=CreateFrame('Frame','RAIDFilterPanel',UIParent,'BackdropTemplate');self.panel=f
    f:SetSize(800,700);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true)
    if UIParent.GetWidth and UIParent.GetHeight then
        local w,h=UIParent:GetWidth(),UIParent:GetHeight();if w and h then f:SetScale(math.min(1,(w-30)/800,(h-30)/700))end
    end
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing)
    f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
    f:SetBackdropColor(.035,.03,.02,.98)
    local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-4,-4);close:SetScript('OnClick',function()f:Hide()end)
    text(f,'RAID  |  Options',22,-18,600,'GameFontNormalLarge')
    text(f,'Changes apply immediately and are saved account-wide.  /rf or /raidfilter',22,-46,740,'GameFontHighlightSmall')
    f.summary=text(f,'',22,-75,750,'GameFontHighlightSmall');f.checks={};f.channelChecks={};f.publicChecks={};f.pages={};f.tabs={}
    f.tabs.rules=button(f,'Rules',22,-104,132,function()R:SetOptionsTab('rules')end)
    f.tabs.channels=button(f,'Channels',162,-104,132,function()R:SetOptionsTab('channels')end)
    f.tabs.keywords=button(f,'Keywords',302,-104,132,function()R:SetOptionsTab('keywords')end)
    f.checks.enabled=check(f,'Enable RAID',610,-103,140,function(b)R:SetFilteringEnabled(b:GetChecked())end)
    for _,key in ipairs({'rules','channels','keywords'})do local page=CreateFrame('Frame',nil,f);page:SetSize(760,400);page:SetPoint('TOPLEFT',20,-146);page:Hide();f.pages[key]=page end
    local rules=f.pages.rules
    local definitions={
        {'guild','Block confirmed OLYMPUS guild members',0,'Matches any guild containing uppercase OLYMPUS. Nearby detection is automatic.'},
        {'words','Keyword filtering',58,'Controls the built-in terms below and your custom keyword list.'},
        {'asmongold','Asmongold',108}, {'asmon','Asmon (also matches "asmon layer")',144},
        {'asmonLayer','The phrase "asmon layer"',180},
        {'han','Chinese / Han characters',246,'Also matches Japanese kanji and other uses of Han characters.'},
        {'cyrillic','Russian / Cyrillic characters',306,'Also matches other languages written in Cyrillic.'},
    }
    for _,row in ipairs(definitions)do
        local key,y=row[1],-row[3];local x=(key=='asmongold' or key=='asmon' or key=='asmonLayer')and 34 or 0
        f.checks[key]=check(rules,row[2],x,y,700-x,function(b)
            R.db.settings[key]=b:GetChecked()and true or false
            if key=='guild' and R.db.settings.enabled and R.db.settings.guild then R:ObserveGroup()end
            R:RefreshPanel()
        end)
        if row[4]then text(rules,row[4],32,y-28,710,'GameFontHighlightSmall')end
    end
    text(rules,'To block only the phrase, turn Asmon off and leave "asmon layer" on. Keywords use whole words, ignoring case.',66,-216,670,'GameFontHighlightSmall')
    text(rules,'Rules apply only to enabled chat types and public channels on the Channels page.',0,-372,750,'GameFontHighlightSmall')
    button(rules,'Manage custom keywords',440,-108,270,function()R:SetOptionsTab('keywords')end)
    local keywords=f.pages.keywords;f.keywordRows={}
    text(keywords,'CUSTOM KEYWORDS',0,0,300,'GameFontNormal')
    text(keywords,'Whole words: boost only. Contains: boosting too.',304,0,446,'GameFontHighlightSmall')
    f.keywordInput=CreateFrame('EditBox',nil,keywords,'InputBoxTemplate');f.keywordInput:SetSize(422,26);f.keywordInput:SetPoint('TOPLEFT',6,-30)
    f.keywordInput:SetAutoFocus(false);f.keywordInput:SetMaxLetters(80)
    f.keywordInput:SetScript('OnEnterPressed',function()R:AddKeywordFromInput()end)
    f.keywordInput:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
    f:SetScript('OnHide',function()f.keywordInput:ClearFocus()end)
    f.keywordMode=button(keywords,'Match: Whole words',444,-31,182,function(b)
        R.keywordMode=R.keywordMode=='contains'and 'whole'or 'contains';b:SetText(R.keywordMode=='contains'and 'Match: Contains'or 'Match: Whole words')
    end)
    f.keywordAdd=button(keywords,'Add',640,-31,110,function()R:AddKeywordFromInput()end)
    f.keywordNotice=text(keywords,'',6,-68,744,'GameFontHighlightSmall')
    text(keywords,'Enabled / word or phrase',0,-102,380,'GameFontNormalSmall')
    text(keywords,'Match mode (click to change)',414,-102,260,'GameFontNormalSmall')
    for i=1,8 do
        local row={};f.keywordRows[i]=row;local y=-122-(i-1)*29
        row.check=check(keywords,'',0,y,366,function(b)
            if row.index then R:SetKeyword(row.index,'enabled',b:GetChecked()and true or false);R:RefreshPanel()end
        end)
        row.check.label:SetHeight(22);row.check.label:SetWordWrap(false)
        row.mode=button(keywords,'',414,y,172,function()
            local entry=row.index and R.db.settings.customKeywords[row.index]
            if entry then R:SetKeyword(row.index,'mode',entry.mode=='contains'and 'whole'or 'contains');R:RefreshPanel()end
        end)
        row.remove=button(keywords,'Remove',602,y,148,function()
            if row.index then R:RemoveKeyword(row.index);R.keywordMessage='Keyword removed.';R:RefreshPanel()end
        end)
    end
    f.keywordPrev=button(keywords,'< Back',0,-360,80,function()R.keywordOffset=math.max(0,(R.keywordOffset or 0)-8);R:RefreshPanel()end)
    f.keywordNext=button(keywords,'Next >',670,-360,80,function()R.keywordOffset=(R.keywordOffset or 0)+8;R:RefreshPanel()end)
    f.keywordPage=text(keywords,'',95,-366,550,'GameFontHighlightSmall')
    f.keywordState=text(keywords,'',0,-395,750,'GameFontHighlightSmall')
    local channels=f.pages.channels
    text(channels,'CHAT TYPES',0,0,350,'GameFontNormal');text(channels,'INDIVIDUAL PUBLIC / CUSTOM CHANNELS',400,0,350,'GameFontNormal')
    text(channels,'Checked = apply enabled blocking rules.',0,-24,350,'GameFontHighlightSmall')
    text(channels,'Public / custom channels must also be checked. New channels follow that switch.',400,-24,350,'GameFontHighlightSmall')
    for i,row in ipairs(self.channelTypes)do
        local key=row[1];f.channelChecks[key]=check(channels,row[2],0,-47-(i-1)*25,340,function(b)R.db.settings.channels[key]=b:GetChecked()and true or false;R:RefreshPanel()end)
    end
    for i=1,8 do
        local b=check(channels,'',400,-70-(i-1)*30,310,function(b)
            if b.channel then R.db.settings.publicChannels[b.channel.key]=b:GetChecked()and true or false end
            R:RefreshPanel()
        end);f.publicChecks[i]=b
    end
    f.channelPrev=button(channels,'<',400,-319,40,function()R.channelOffset=math.max(0,(R.channelOffset or 0)-8);R:RefreshPanel()end)
    f.channelNext=button(channels,'>',710,-319,40,function()R.channelOffset=(R.channelOffset or 0)+8;R:RefreshPanel()end)
    f.channelPage=text(channels,'',450,-325,250,'GameFontHighlightSmall')
    for i,value in ipairs({true,false})do
        local enabled=value
        button(channels,enabled and 'Types: all on' or 'Types: all off',(i-1)*174,-375,166,function()
            for _,row in ipairs(R.channelTypes)do R.db.settings.channels[row[1]]=enabled end;R:RefreshPanel()
        end)
        button(channels,enabled and 'Listed: all on' or 'Listed: all off',400+(i-1)*179,-354,171,function()
            for _,row in ipairs(R:ChannelRows())do R.db.settings.publicChannels[row.key]=enabled end;R:RefreshPanel()
        end)
    end
    text(channels,'Joined channels update automatically. Unjoined saved channels stay listed. No channel numbers are saved.',400,-388,350,'GameFontHighlightSmall')
    f.counts=text(f,'',22,-574,750,'GameFontHighlightSmall')
    button(f,'Refresh nearby guilds',22,-600,188,function()R:ScanGuilds();R:RefreshPanel()end)
    button(f,'Clear guild cache',218,-600,163,function()R:ClearGuilds();R:RefreshPanel()end)
    button(f,'Reset counts',389,-600,140,function()R.stats={guild=0,words=0,han=0,cyrillic=0};R:RefreshPanel()end)
    f.minimapCheck=check(f,'Minimap button',554,-598,200,function(b)R:SetMinimapShown(b:GetChecked())end)
    f.status=text(f,'',22,-638,750,'GameFontHighlightSmall')
    text(f,'Chat has no guild field. Unseen senders need confirmed guild data before guild blocking can apply.',22,-669,750,'GameFontHighlightSmall')
    local elapsed=0;f:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;R:RefreshPanel()end end)
    UISpecialFrames[#UISpecialFrames+1]='RAIDFilterPanel';self:RefreshPanel();f:Show()
end
