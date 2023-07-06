-- 获取当前响应数据
local chunk, eof = ngx.arg[1], ngx.arg[2]

ngx.log(ngx.DEBUG,"chunk==" .. chunk)

-- 定义全局变量，收集全部响应
if ngx.ctx.buffered == nil then
    ngx.ctx.buffered = {}
end

-- 如果非最后一次响应，将当前响应赋值
if chunk ~= "" and not ngx.is_subrequest then
    table.insert(ngx.ctx.buffered, chunk)

    -- 将当前响应赋值为空，以修改后的内容作为最终响应
    ngx.arg[1] = nil
end

-- 如果为最后一次响应，对所有响应数据进行处理
if eof then
    -- 获取所有响应数据
    local whole = table.concat(ngx.ctx.buffered)
    ngx.ctx.buffered = nil

    --设置缓存时间，默认5s
    local cache_time = ngx.var.cache_time	--读取nginx缓存时间配置
    if(cache_time == nil) then
        cache_time = 5
    else
        cache_time = tonumber(cache_time)
    end

		--获取根据参数生成的缓存key
		local cacheKeyLua = require("cacheKey")
		local cache_key = cacheKeyLua.execute(ngx, "response")
    if(cache_key == nil) then
        ngx.log(ngx.ERR,"cache_key is nil")
        return
    end

    --nginx本地缓存
    local nginx_local_cache = ngx.shared.my_cache
    if(nginx_local_cache == nil) then
        ngx.log(ngx.ERR,"nginx_local_cache is nil")
        return
    end

    -- http status
    local my_status = ngx.status
    
    --业务状态码 参数
    local business_status_param = ngx.var.business_status_param	--读取是否使用业务码做缓存
    if(business_status_param ~= nil) then
        local cjson = require("cjson")
        -- 如果能够解析json，则进行缓存，不能就不进行缓存了
        
        local status, response_json = pcall(function() return cjson.decode(whole) end)
        if status then
            -- local response_json = cjson.decode(whole)
            if(type(response_json)=="table") then
                local business_status = response_json[business_status_param]
                if(business_status~=200) then
                    my_status = business_status
                end
            end
        else
            my_status = 500
        end

    end
    
    -- 只缓存正确状态码下的参数
    if(my_status == 200) then
    	nginx_local_cache:set(cache_key,whole,cache_time)
    end
    
    
    --处理header
    local headers = ngx.resp.get_headers()
    for k, v in pairs(headers) do
    		if(k == "content-length" or k == "Content-length") then
    				nginx_local_cache:set(cache_key.."_content-length",v)
    		end 
    		if(k == "content-type" or k == "Content-type") then
    				nginx_local_cache:set(cache_key.."_content-type",v)
    		end 
    		
    end
    
    --记录日志
    local cache_value_size = string.len(whole)
    cacheKeyLua.logOutput(ngx.var.uri, cache_key, "False", nginx_local_cache:get(cache_key.."_content-length"), cache_value_size)
    
    ngx.arg[1] = whole

end

