local _,R=...
local defaultAngle=195

function R:EnsureMinimapSettings()
    local db=self.db
    db.minimap=type(db.minimap)=='table' and db.minimap or {}
    local angle=db.minimap.angle
    if type(angle)~='number' or angle~=angle or math.abs(angle)==math.huge then angle=defaultAngle end
    db.minimap.angle=angle%360
    db.minimap.hide=db.minimap.hide==true
    return db.minimap
end
function R:InitMinimap()
    self:EnsureMinimapSettings();self:CreateMinimapButton()
end

function R:PositionMinimapButton()
    local b=self.minimapButton;if not b or not Minimap then return end
    local angle=math.rad(self:EnsureMinimapSettings().angle);local x,y=math.cos(angle),math.sin(angle)
    if GetMinimapShape and GetMinimapShape()=='SQUARE' then
        local edge=math.max(math.abs(x),math.abs(y));x=x/edge;y=y/edge
    end
    b:ClearAllPoints()
    b:SetPoint('CENTER',Minimap,'CENTER',(Minimap:GetWidth()/2+8)*x,(Minimap:GetHeight()/2+8)*y)
end

function R:DragMinimapButton()
    local cx,cy=Minimap:GetCenter();if not cx or not cy then return end
    local x,y=GetCursorPosition();local scale=Minimap:GetEffectiveScale()
    if not scale or scale<=0 then return end
    x=x/scale-cx;y=y/scale-cy;if x==0 and y==0 then return end
    local angle
    if x==0 then angle=y>0 and math.pi/2 or -math.pi/2
    else angle=math.atan(y/x);if x<0 then angle=angle+math.pi end end
    self.db.minimap.angle=math.deg(angle)%360;self:PositionMinimapButton()
end

function R:MinimapStatus()
    if not self.db.settings.enabled then return 'Filtering paused',false end
    if (self.registered or 0)==0 then return 'Filtering unavailable',false end
    for _,row in ipairs(self.channelTypes)do
        if self.db.settings.channels[row[1]] then return 'Filtering enabled',true end
    end
    return 'All chat types disabled',false
end

function R:ShowMinimapTooltip()
    if not GameTooltip then return end
    local status,active=self:MinimapStatus()
    GameTooltip:SetOwner(self.minimapButton,'ANCHOR_LEFT');GameTooltip:SetText('RAID')
    GameTooltip:AddLine(status,active and .5 or 1,active and 1 or .75,.4)
    GameTooltip:AddLine('Left-click: open / close options',1,.85,.55)
    GameTooltip:AddLine('Right-click: pause / resume filtering',1,.85,.55)
    GameTooltip:AddLine('Drag: move around the minimap',1,.85,.55)
    GameTooltip:Show()
end

function R:UpdateMinimapButton()
    local b=self.minimapButton;if not b then return end
    self:EnsureMinimapSettings()
    local _,active=self:MinimapStatus();b.icon:SetDesaturated(not active)
    b.icon:SetAlpha(active and 1 or .55)
    b:SetShown(not self.db.minimap.hide)
    if b.hovered and not self.db.minimap.hide then self:ShowMinimapTooltip() end
end

function R:SetMinimapShown(show)
    self:EnsureMinimapSettings().hide=not show
    self:CreateMinimapButton();self:RefreshPanel()
end

function R:SetFilteringEnabled(enabled)
    self.db.settings.enabled=enabled and true or false
    if self.db.settings.enabled and self.db.settings.guild then self:ObserveGroup() end
    self:RefreshPanel()
end

function R:CreateMinimapButton()
    if self.minimapButton or not Minimap then return end
    self:EnsureMinimapSettings()
    local b=CreateFrame('Button','RAIDFilterMinimapButton',Minimap);self.minimapButton=b
    b:SetSize(32,32);b:SetFrameStrata('MEDIUM');b:SetFrameLevel(Minimap:GetFrameLevel()+8)
    b:RegisterForClicks('LeftButtonUp','RightButtonUp');b:RegisterForDrag('LeftButton')
    local icon=b:CreateTexture(nil,'ARTWORK');b.icon=icon;icon:SetSize(20,20);icon:SetPoint('CENTER',0,0)
    icon:SetTexture('Interface\\Icons\\INV_Shield_05')
    local border=b:CreateTexture(nil,'OVERLAY');border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
    border:SetSize(54,54);border:SetPoint('TOPLEFT',0,0)
    b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
    b:SetScript('OnMouseDown',function()b.dragged=false end)
    b:SetScript('OnClick',function(_,button)
        if b.dragged then b.dragged=false;return end
        if button=='RightButton' then
            R:SetFilteringEnabled(not R.db.settings.enabled)
            R:Print(R.db.settings.enabled and 'Filtering enabled.' or 'Filtering paused.')
        else R:TogglePanel() end
    end)
    b:SetScript('OnDragStart',function(s)
        s.dragged=true;s.hovered=false;if GameTooltip then GameTooltip:Hide() end
        s:SetScript('OnUpdate',function()R:DragMinimapButton()end)
    end)
    b:SetScript('OnDragStop',function(s)R:DragMinimapButton();s:SetScript('OnUpdate',nil)end)
    b:SetScript('OnHide',function(s)
        s:SetScript('OnUpdate',nil)
        if s.hovered and GameTooltip then GameTooltip:Hide()end;s.hovered=false
    end)
    b:SetScript('OnEnter',function(s)s.hovered=true;R:ShowMinimapTooltip()end)
    b:SetScript('OnLeave',function(s)s.hovered=false;if GameTooltip then GameTooltip:Hide()end end)
    Minimap:HookScript('OnSizeChanged',function()R:PositionMinimapButton()end)
    self:PositionMinimapButton();self:UpdateMinimapButton()
end
