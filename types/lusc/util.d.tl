
local record util
   record TryOpts<T>
      action:function():T
      catch:function(err:any):T
      finally:function()
   end

   is_log_enabled:function():boolean
   log:function(format:string, ...:any)
   set_log_handler:function(log_handler:function(string))
   map_is_empty:function<K, V>(values:{K:V}):boolean
   binary_search:function<T>(items:{T}, item:T, comparator:function(T, T):integer):integer
   assert:function(condition:boolean, format:string, ...:any)
   assert_throws:function(action:function())
   is_instance:function(obj:any, cls:any):boolean
   index_of:function<T>(list:{T}, item:T):integer
   remove_element:function<T>(list:{T}, item:T)
   clear_table:function<K, V>(values:{K:V})
   partial_func1:function<P1, TReturn>(action:(function(P1):TReturn), p1:P1):(function():TReturn)
   try:function<T>(t:util.TryOpts<T>):T
   shallow_clone:function<T>(source:T):T
end

return util
