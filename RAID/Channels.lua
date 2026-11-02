local _,R=...
R.channelTypes={
 {'say','Say',{'CHAT_MSG_SAY'}}, {'yell','Yell',{'CHAT_MSG_YELL'}},
 {'public','Public / custom channels',{'CHAT_MSG_CHANNEL'}},
 {'guild','Guild chat',{'CHAT_MSG_GUILD'}}, {'officer','Officer chat',{'CHAT_MSG_OFFICER'}},
 {'whisper','Incoming whispers',{'CHAT_MSG_WHISPER'}},
 {'party','Party + party leader',{'CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER'}},
 {'raid','Raid + raid leader',{'CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER'}},
 {'warning','Raid warnings',{'CHAT_MSG_RAID_WARNING'}},
 {'instance','Instance groups + leader',{'CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER'}},
 {'battleground','Battleground + leader',{'CHAT_MSG_BATTLEGROUND','CHAT_MSG_BATTLEGROUND_LEADER'}},
 {'emote','Emotes',{'CHAT_MSG_EMOTE','CHAT_MSG_TEXT_EMOTE'}},
 {'bnet','Battle.net whispers / conversations',{'CHAT_MSG_BN_WHISPER','CHAT_MSG_BN_CONVERSATION'}},
}
R.eventChannels={}
for _,row in ipairs(R.channelTypes)do for _,event in ipairs(row[3])do R.eventChannels[event]=row[1] end end
function R:InitChannels()
 local s=self.db.settings
 s.channels=type(s.channels)=='table' and s.channels or {}
 s.publicChannels=type(s.publicChannels)=='table' and s.publicChannels or {}
 for _,row in ipairs(self.channelTypes)do if type(s.channels[row[1]])~='boolean'then s.channels[row[1]]=true end end
 for key,value in pairs(s.publicChannels)do if type(key)~='string' or type(value)~='boolean'then s.publicChannels[key]=nil end end
 self.joinedChannels={}
 self:RefreshChannels()
end
function R:ChannelKey(name)
 if type(name)~='string' then return end
 name=name:match('^%s*(.-)%s*$'):lower()
 -- English default channels can include a zone suffix. Custom names stay exact.
 local base=name:match('^(.-) %- ')
 if base and (base=='general' or base=='trade' or base=='localdefense' or base=='worlddefense' or base=='lookingforgroup')then name=base end
 return name~='' and name or nil
end
function R:RefreshChannels()
 local joined={}
 if GetChannelList then
  local list={GetChannelList()}
  for i=1,#list,3 do
   local id,name=list[i],list[i+1];local key=self:ChannelKey(name)
   if key and type(id)=='number' and id>0 then joined[key]={id=id,name=name,key=key,joined=true} end
  end
 end
 self.joinedChannels=joined
end
function R:ChannelRows()
 local out,seen={},{}
 for key,row in pairs(self.joinedChannels)do out[#out+1]=row;seen[key]=true end
 for key in pairs(self.db.settings.publicChannels)do if not seen[key]then out[#out+1]={key=key,name=key,joined=false}end end
 table.sort(out,function(a,b)if a.joined~=b.joined then return a.joined end;return a.key<b.key end)
 return out
end
function R:ChannelEnabled(event,baseName,index)
 local key=self.eventChannels[event];local s=self.db.settings
 if not key or s.channels[key]==false then return false end
 if key=='public' then
  local name=self:ChannelKey(baseName)
  if not name and index then for k,row in pairs(self.joinedChannels)do if row.id==index then name=k;break end end end
  if name and s.publicChannels[name]==false then return false end
 end
 return true
end
