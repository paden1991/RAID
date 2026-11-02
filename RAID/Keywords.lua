local _,R=...
R.keywordLimit=100
function R:NormalizeKeyword(value)
 if type(value)~='string'then return end
 value=value:gsub('%s+',' '):match('^%s*(.-)%s*$')
 if value==''then return nil,'Enter a word or phrase first.'end
 if #value>80 then return nil,'That keyword is too long. Try a shorter word or phrase.'end
 if value:find('%c')then return nil,'Remove control characters from the keyword.'end
 return value,value:lower()
end
local function word(b)return b and (b>=48 and b<=57 or b>=65 and b<=90 or b>=97 and b<=122 or b==95 or b>=128)end
function R:RebuildKeywords()
 self.keywordMatchers={}
 for _,entry in ipairs(self.db.settings.customKeywords)do
  if entry.enabled then
   local key=entry.text:lower()
   self.keywordMatchers[#self.keywordMatchers+1]={key=key,mode=entry.mode,left=word(key:byte(1)),right=word(key:byte(-1))}
  end
 end
end
function R:InitKeywords()
 local saved=self.db.settings.customKeywords;local rows,seen={},{}
 if type(saved)=='table'then
  for _,entry in ipairs(saved)do
   if type(entry)=='table'then
    local value,key=self:NormalizeKeyword(entry.text)
    if value and not seen[key]and #rows<self.keywordLimit then
     rows[#rows+1]={text=value,enabled=entry.enabled~=false,mode=entry.mode=='contains'and 'contains'or 'whole'};seen[key]=true
    end
   end
  end
 end
 self.db.settings.customKeywords=rows;self:RebuildKeywords()
end
function R:AddKeyword(value,mode)
 local text,key=self:NormalizeKeyword(value);if not text then return false,key end
 local rows=self.db.settings.customKeywords
 for i,entry in ipairs(rows)do if entry.text:lower()==key then return false,'That keyword is already listed.',i end end
 if #rows>=self.keywordLimit then return false,'The list is full. Remove an unused keyword first.'end
 rows[#rows+1]={text=text,mode=mode=='contains'and 'contains'or 'whole',enabled=true}
 self:RebuildKeywords();return true,'Keyword added.',#rows
end
function R:RemoveKeyword(index)
 local rows=self.db.settings.customKeywords
 if type(index)~='number'or index%1~=0 or index<1 or index>#rows then return false end
 table.remove(rows,index);self:RebuildKeywords();return true
end
function R:SetKeyword(index,field,value)
 local entry=self.db.settings.customKeywords[index];if not entry then return false end
 if field=='enabled'then entry.enabled=value==true
 elseif field=='mode'and (value=='whole'or value=='contains')then entry.mode=value
 else return false end
 self:RebuildKeywords();return true
end
function R:CustomKeywordMatches(text)
 if not self.keywordMatchers or #self.keywordMatchers==0 then return false end
 text=text:lower():gsub('%s+',' ')
 for _,entry in ipairs(self.keywordMatchers)do
  local start=1
  while start<=#text do
   local a,b=text:find(entry.key,start,true);if not a then break end
   if entry.mode=='contains'or
       (not entry.left or not word(text:byte(a-1)))and(not entry.right or not word(text:byte(b+1)))then return true end
   start=a+1
  end
 end
 return false
end
