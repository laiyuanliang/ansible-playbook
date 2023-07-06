local cjson = require("cjson")
local _M = {}

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

local function toKey(cache_key_array, mytable)    
    for k,v in pairs(mytable) do
        if(type(v) ~= "table") then
            table.insert(cache_key_array,k.."_"..tostring(v))
        else
            table.insert(cache_key_array,k)
            toKey(cache_key_array, v)
        end 
    end
end

function _M.execute(ngx, methodtype)
    --组成缓存key的数据数组
    local cache_key_array = {}

    local request_uri = ngx.var.uri
    table.insert(cache_key_array,request_uri)

    --获取header参数，作为key的一部分
    local header_param = ngx.var.header_param  --读取nginx需要缓存的header
    local headers_inner=ngx.req.get_headers()
    if(header_param ~= nil) then
        ngx.log(ngx.DEBUG,"header_param=="..header_param)
        local header_array = split(header_param,"#")
        for i,v in ipairs(header_array) do
            local header_value=headers_inner[v]
            if header_value ~= nil then
                table.insert(cache_key_array,v.."_"..header_value)
            end
        end
    end

    --获取请求参数，作为key的一部分
    local request_method = ngx.var.request_method
    local args = nil
    if request_method == "GET" then
        args = ngx.req.get_uri_args()
    elseif request_method == "POST" then
    		if methodtype == "request" then
        		ngx.req.read_body()
        end
        args = ngx.req.get_body_data() 
        args = cjson.decode(args)
    end


    local request_param = ngx.var.request_param  --读取nginx需要缓存的request参数
    if request_param == nil then
        toKey(cache_key_array, args)
    else
        local request_array = split(request_param,"#")
        for i,v in ipairs(request_array) do
            local request_value=args[v]
            if request_value ~= nil then
                table.insert(cache_key_array,v.."_"..request_value)
            end
        end
    end

    -- 添加商户域名添加到key后面
    -- 添加此参数作用于单独商户，根据域名做缓存，不能多商户使用同一域名
    local req_merchant = ngx.var.request_merchant
    if (req_merchant == "1") then
        table.insert(cache_key_array,ngx.var.http_host)
    end

    local cache_key_array_str = table.concat(cache_key_array, '_')
    ngx.log(ngx.DEBUG,"cache_key_array=="..cache_key_array_str)

    return cache_key_array_str
end

function _M.logOutput(uri,key,is_cached,size,body_size)
    if size == nil then
        size = "0"
    end
    local outputjson = '{"uri": "' .. uri .. '", "key":"'.. key .. '", "is_cached": "' .. is_cached .. '", "size":"' .. size ..'", "body_size":"' .. body_size ..'"}'
    ngx.log(ngx.INFO,"cache_response_v1:" .. outputjson)

end

return _M
