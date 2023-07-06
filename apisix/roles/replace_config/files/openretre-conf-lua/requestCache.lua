local cjson = require("cjson")

--字符串分隔
local function split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

--nginx本地缓存
local nginx_local_cache = ngx.shared.my_cache
if(nginx_local_cache == nil) then
	ngx.log(ngx.ERR,"nginx_local_cache is nil")
	return
end

--获取根据参数生成的缓存key
local cacheKeyLua = require("cacheKey")
local cache_key = cacheKeyLua.execute(ngx, "request")

ngx.log(ngx.DEBUG,"cache key: " .. cache_key)

--从本地缓存中取数据
local cache_value = nginx_local_cache:get(cache_key)
local cache_content_type_value = nginx_local_cache:get(cache_key.."_content-type")
local cache_content_length_value = nginx_local_cache:get(cache_key.."_content-length")
local cache_header = nginx_local_cache:get(cache_key .. "_header")
if(cache_header ~= nil) then
    ngx.log(ngx.DEBUG,"cache_header: " .. cache_header)
else
    ngx.log(ngx.DEBUG,"cache_header is nil")
end
local cache_header_array = split(cache_header, "@@")


if(cache_value ~= nil) then
    local cache_value_size = string.len(cache_value)
    -- 日志记录
    cacheKeyLua.logOutput(ngx.var.uri, cache_key, "True", cache_content_length_value, cache_value_size)
    
    ngx.header["content-type"] = cache_content_type_value
    --ngx.header["content-length"] = cache_content_length_value
    for i,v in ipairs(cache_header_array) do 
    		ngx.log(ngx.DEBUG,"cache_header_array: " .. i)
    		ngx.header[i] = nginx_local_cache:get(cache_key .. "_" .. i)
    end 
    
    ngx.log(ngx.DEBUG,"cache_value: " .. cache_value)
    ngx.say(cache_value)
    ngx.exit(ngx.HTTP_OK)
else
    --如果数据不存在，去后端请求
    ngx.log(ngx.DEBUG,"no cache")
    ngx.exec("@cache_response")
end

