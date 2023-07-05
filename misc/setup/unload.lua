for k,v in pairs(package.loaded) do
  if k:match("^libapp") then package.loaded[k] = nil end
end