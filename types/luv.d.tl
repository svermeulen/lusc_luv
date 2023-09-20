
-- see docs here
-- https://github.com/luvit/luv/blob/master/docs.md

local record uv
   version:function():integer
   version_string:function():string

   -- Loop - Event loop
   loop_close:function():integer, string

   enum RunModes
      "default"
      "once"
      "nowait"
   end

   run:function(mode:RunModes):boolean, string

   record Req
      cancel:function(Req):integer, string
      req_get_type:function(Req):string, integer
   end

   record Handle
      is_active:function(Handle):boolean, string
      is_closing:function(Handle):boolean, string
      close:function(Handle, callback:function())
      ref:function(Handle)
      unref:function(Handle)
      has_ref:function(Handle):boolean, string
      send_buffer_size:function(Handle, size:integer):integer, string
      recv_buffer_size:function(Handle, size:integer):integer, string
      fileno:function(Handle):integer, string
      get_type:function(Handle):string
   end

   loop_configure:function(option:string, ...:any):integer, string
   loop_mode:function():string
   loop_alive:function():boolean, string
   stop:function()
   backend_fd:function():integer
   backend_timeout:function():integer
   now:function():integer
   update_time:function()
   walk:function(function(handle:Handle))

   -- reference counting

   record Timer
      -- Handle functions
      is_active:function(Timer):boolean, string
      is_closing:function(Timer):boolean, string
      close:function(Timer, callback:function())
      ref:function(Timer)
      unref:function(Timer)
      has_ref:function(Timer):boolean, string
      send_buffer_size:function(Timer, size:integer):integer, string
      recv_buffer_size:function(Timer, size:integer):integer, string
      fileno:function(Timer):integer, string
      get_type:function(Timer):string, integer

      start:function(Timer, timeout:integer, rep:integer, callback:function()):integer, string
      stop:function(Timer):integer, string
      again:function(Timer):integer, string
      set_repeat:function(Timer, rep:integer)
      get_repeat:function(Timer):integer
      get_due_in:function(Timer):integer
   end

   new_timer:function():Timer

   record Prepare
      -- Handle functions
      is_active:function(Prepare):boolean, string
      is_closing:function(Prepare):boolean, string
      close:function(Prepare, callback:function())
      ref:function(Prepare)
      unref:function(Prepare)
      has_ref:function(Prepare):boolean, string
      send_buffer_size:function(Prepare, size:integer):integer, string
      recv_buffer_size:function(Prepare, size:integer):integer, string
      fileno:function(Prepare):integer, string
      get_type:function(Prepare):string, integer

      start:function(Prepare, callback:function()):integer, string
      stop:function(Prepare):integer, string
   end

   -- Prepare handles will run the given callback once per loop iteration, right before polling for I/O.
   new_prepare:function():Prepare, string

   record Check
      -- Handle functions
      is_active:function(Check):boolean, string
      is_closing:function(Check):boolean, string
      close:function(Check, callback:function())
      ref:function(Check)
      unref:function(Check)
      has_ref:function(Check):boolean, string
      send_buffer_size:function(Check, size:integer):integer, string
      recv_buffer_size:function(Check, size:integer):integer, string
      fileno:function(Check):integer, string
      get_type:function(Check):string, integer

      start:function(Check, callback:function()):integer, string
      stop:function():integer, string
   end

   -- Check handles will run the given callback once per loop iteration, right after polling for I/O.
   new_check:function():Check, string

   record Idle
      -- Handle functions
      is_active:function(Idle):boolean, string
      is_closing:function(Idle):boolean, string
      close:function(Idle, callback:function())
      ref:function(Idle)
      unref:function(Idle)
      has_ref:function(Idle):boolean, string
      send_buffer_size:function(Idle, size:integer):integer, string
      recv_buffer_size:function(Idle, size:integer):integer, string
      fileno:function(Idle):integer, string
      get_type:function(Idle):string, integer

      start:function(Idle, callback:function()):integer, string
      stop:function():integer, string
   end

   -- Idle handles will run the given callback once per loop iteration, right before the Prepare handles.
   new_idle:function():Idle, string

   record Async
      -- Handle functions
      is_active:function(Async):boolean, string
      is_closing:function(Async):boolean, string
      close:function(Async, callback:function())
      ref:function(Async)
      unref:function(Async)
      has_ref:function(Async):boolean, string
      send_buffer_size:function(Async, size:integer):integer, string
      recv_buffer_size:function(Async, size:integer):integer, string
      fileno:function(Async):integer, string
      get_type:function(Async):string, integer

      send:function(Async, ...:any):integer, string
   end

   new_async:function(callback:function()):Async, string

   record Poll
      -- Handle functions
      is_active:function(Poll):boolean, string
      is_closing:function(Poll):boolean, string
      close:function(Poll, callback:function())
      ref:function(Poll)
      unref:function(Poll)
      has_ref:function(Poll):boolean, string
      send_buffer_size:function(Poll, size:integer):integer, string
      recv_buffer_size:function(Poll, size:integer):integer, string
      fileno:function(Poll):integer, string
      get_type:function(Poll):string, integer

      start:function(Poll, events:string, callback:function()):integer, string
      stop:function(Poll):integer, string
   end

   -- Poll handles are used to watch file descriptors for readability and writability, similar to the purpose of poll(2).
   new_poll:function(fd:integer):Poll, string
   new_socket_poll:function(fd:integer):Poll, string

   record Signal
      -- Handle functions
      is_active:function(Signal):boolean, string
      is_closing:function(Signal):boolean, string
      close:function(Signal, callback:function())
      ref:function(Signal)
      unref:function(Signal)
      has_ref:function(Signal):boolean, string
      send_buffer_size:function(Signal, size:integer):integer, string
      recv_buffer_size:function(Signal, size:integer):integer, string
      fileno:function(Signal):integer, string
      get_type:function(Signal):string, integer

      start:function(Signal, signum:integer, callback:function()):integer, string
      start_oneshot:function(Signal, signum:integer, callback:function()):integer, string
      stop:function(Signal):integer, string
   end

   -- Signal handles implement Unix style signal handling on a per-event loop bases.
   new_signal:function():Signal, string

   record Process
      -- Handle functions
      is_active:function(Process):boolean, string
      is_closing:function(Process):boolean, string
      close:function(Process, callback:function())
      ref:function(Process)
      unref:function(Process)
      has_ref:function(Process):boolean, string
      send_buffer_size:function(Process, size:integer):integer, string
      recv_buffer_size:function(Process, size:integer):integer, string
      fileno:function(Process):integer, string
      get_type:function(Process):string, integer

      kill:function(signum:integer):integer, string
      get_pid:function():integer
   end

   -- Process handles will spawn a new process and allow the user to control it and establish communication channels with it using streams.
   disable_stdio_inheritance:function()

   record SpawnOptions
      -- Use of any here means type is unclear from docs
      args:{string}
      stdio:any
      env:any
      cwd:string
      uid:any
      gid:any
      verbatim:boolean
      detached:boolean
      hide:boolean
   end

   spawn:function(path:string, options:SpawnOptions, on_exit:function(integer)):Process, integer

   -- Stream handles provide an abstraction of a duplex communication channel. Stream is an abstract type, libuv provides 3 stream implementations in the form of Tcp, Pipe and Tty.
   record Stream
      -- Handle functions
      is_active:function(Stream):boolean, string
      is_closing:function(Stream):boolean, string
      close:function(Stream, callback:function())
      ref:function(Stream)
      unref:function(Stream)
      has_ref:function(Stream):boolean, string
      send_buffer_size:function(Stream, size:integer):integer, string
      recv_buffer_size:function(Stream, size:integer):integer, string
      fileno:function(Stream):integer, string
      get_type:function(Stream):string, integer

      -- Stream functions
      shutdown:function(Stream, callback:function())
      listen:function(Stream, backlog:integer, callback:function()):integer, string
      accept:function(Stream, client_stream:Stream):integer, string
      read_start:function(Stream, callback:function())
      read_stop:function(Stream)
      write:function(Stream, data:any, callback:function()):any, string
      write2:function(Stream, data:any, send_handle:Stream, callback:function())
      try_write:function(Stream, data:any):integer, string
      try_write2:function(Stream, data:any, send_handle:Stream):integer, string
      is_readable:function(Stream):boolean
      is_writable:function(Stream):boolean
      set_blocking:function(Stream, blocking:boolean):integer, string
      get_write_queue_size:function(Stream):integer
   end

   record Tcp
      -- Handle functions
      is_active:function(Tcp):boolean, string
      is_closing:function(Tcp):boolean, string
      close:function(Tcp, callback:function())
      ref:function(Tcp)
      unref:function(Tcp)
      has_ref:function(Tcp):boolean, string
      send_buffer_size:function(Tcp, size:integer):integer, string
      recv_buffer_size:function(Tcp, size:integer):integer, string
      fileno:function(Tcp):integer, string
      get_type:function(Tcp):string, integer

      -- Stream functions
      shutdown:function(Tcp, callback:function())
      listen:function(Tcp, backlog:integer, callback:function()):integer, string
      accept:function(Tcp, client_stream:Tcp):integer, string
      read_start:function(Tcp, callback:function())
      read_stop:function(Tcp)
      write:function(Tcp, data:any, callback:function()):any, string
      write2:function(Tcp, data:any, send_handle:Tcp, callback:function())
      try_write:function(Tcp, data:any):integer, string
      try_write2:function(Tcp, data:any, send_handle:Tcp):integer, string
      is_readable:function(Tcp):boolean
      is_writable:function(Tcp):boolean
      set_blocking:function(Tcp, blocking:boolean):integer, string
      get_write_queue_size:function(Tcp):integer

      open:function(Tcp, sock:integer):integer, string
      nodelay:function(Tcp, enable:boolean):integer, string
      keepalive:function(Tcp, enable:boolean, delay:integer):integer, string
      simultaneous_accepts:function(Tcp, enable:boolean):integer, string
      bind:function(Tcp, host:string, port:integer, flags:{string:any}):integer, string
      getpeername:function(Tcp):{string:any}, string
      getsockname:function(Tcp):{string:any}, string
      connect:function(Tcp, host:string, port:integer, callback:function()):any, string
      close_reset:function(callback:function())
   end

   -- TCP handles are used to represent both TCP streams and servers.
   new_tcp:function(flags:string):Tcp
   socketpair:function(socktype:string|integer, protocol:string|integer, flags1:{string:any}, flags2:{string:any}):{string:any}, string

   -- Pipe handles provide an abstraction over local domain sockets on Unix and named pipes on Windows.
   record Pipe
      -- Handle functions
      is_active:function(Pipe):boolean, string
      is_closing:function(Pipe):boolean, string
      close:function(Pipe, callback:function())
      ref:function(Pipe)
      unref:function(Pipe)
      has_ref:function(Pipe):boolean, string
      send_buffer_size:function(Pipe, size:integer):integer, string
      recv_buffer_size:function(Pipe, size:integer):integer, string
      fileno:function(Pipe):integer, string
      get_type:function(Pipe):string, integer

      -- Stream functions
      shutdown:function(Pipe, callback:function())
      listen:function(Pipe, backlog:integer, callback:function()):integer, string
      accept:function(Pipe, client_stream:Pipe):integer, string
      read_start:function(Pipe, callback:function(string, string))
      read_stop:function(Pipe)
      write:function(Pipe, data:any, callback:function()):any, string
      write2:function(Pipe, data:any, send_handle:Pipe, callback:function())
      try_write:function(Pipe, data:any):integer, string
      try_write2:function(Pipe, data:any, send_handle:Pipe):integer, string
      is_readable:function(Pipe):boolean
      is_writable:function(Pipe):boolean
      set_blocking:function(Pipe, blocking:boolean):integer, string
      get_write_queue_size:function(Pipe):integer

      -- Pipe functions
      open:function(Pipe, fd:integer):integer, string
      bind:function(Pipe, name:string):integer, string
      connect:function(Pipe, name:string, callback:function()):any, string
      getsockname:function(Pipe):string, string
      pending_instances:function(Pipe, count:integer)
      pending_count:function(Pipe):integer
      pending_type:function(Pipe):string
      chmod:function(Pipe, flags:string):integer, string
      bind2:function(Pipe, name:string, flags:any):integer, string
      connect2:function(Pipe, name:string, flags:any, callback:function()):any, string
   end

   new_pipe:function(ipc:boolean):Pipe
   pipe:function(read_flags:any, write_flags:any):any

   record Tty
      -- Handle functions
      is_active:function(Tty):boolean, string
      is_closing:function(Tty):boolean, string
      close:function(Tty, callback:function())
      ref:function(Tty)
      unref:function(Tty)
      has_ref:function(Tty):boolean, string
      send_buffer_size:function(Tty, size:integer):integer, string
      recv_buffer_size:function(Tty, size:integer):integer, string
      fileno:function(Tty):integer, string
      get_type:function(Tty):string, integer

      -- Stream functions
      shutdown:function(Tty, callback:function())
      listen:function(Tty, backlog:integer, callback:function()):integer, string
      accept:function(Tty, client_stream:Tty):integer, string
      read_start:function(Tty, callback:function(err:string, chunk:string))
      read_stop:function(Tty)
      write:function(Tty, data:any, callback:function()):any, string
      write2:function(Tty, data:any, send_handle:Tty, callback:function())
      try_write:function(Tty, data:any):integer, string
      try_write2:function(Tty, data:any, send_handle:Tty):integer, string
      is_readable:function(Tty):boolean
      is_writable:function(Tty):boolean
      set_blocking:function(Tty, blocking:boolean):integer, string
      get_write_queue_size:function(Tty):integer

      set_mode:function(Tty, mode:integer)
      get_winsize:function(Tty):integer, integer | string
   end

   new_tty:function(fd:integer, readable:boolean):Tty, string
   tty_reset_mode:function():integer, string
   tty_set_vterm_state:function(state:string)
   tty_get_vterm_state:function():string, string

   record Udp
      -- Handle functions
      is_active:function(Udp):boolean, string
      is_closing:function(Udp):boolean, string
      close:function(Udp, callback:function())
      ref:function(Udp)
      unref:function(Udp)
      has_ref:function(Udp):boolean, string
      send_buffer_size:function(Udp, size:integer):integer, string
      recv_buffer_size:function(Udp, size:integer):integer, string
      fileno:function(Udp):integer, string
      get_type:function(Udp):string, integer

      get_send_queue_size:function(Udp):integer
      get_send_queue_count:function(Udp):integer
      open:function(Udp, fd:integer):integer, string
      bind:function(Udp, host:string, port:integer, flags:any):integer, string
      getsockname:function(Udp):any
      getpeername:function(Udp):any
      set_membership:function(Udp, multicast_addr:string, interface_addr:string, membership:string):integer, string
      set_source_membership:function(Udp, multicast_addr:string, interface_addr:string, source_addr:string, membership:string):integer, string
      set_multicast_loop:function(Udp, on:boolean):integer, string
      set_multicast_ttl:function(Udp, ttl:integer):integer, string
      set_multicast_interface:function(Udp, interface_addr:string):integer, string
      set_broadcast:function(Udp, on:boolean):integer, string
      set_ttl:function(Udp, ttl:integer):integer, string
      send:function(Udp, data:any, host:string, port:integer, callback:function()):any, string
      try_send:function(Udp, data:any, host:string, port:integer):integer, string
      recv_start:function(Udp, callback:function()):integer, string
      recv_stop:function(Udp):integer, string
      connect:function(Udp, host:string, port:integer):integer, string
   end

   new_udp:function(flags:any):Udp

   record FsEvent
      -- Handle functions
      is_active:function(FsEvent):boolean, string
      is_closing:function(FsEvent):boolean, string
      close:function(FsEvent, callback:function())
      ref:function(FsEvent)
      unref:function(FsEvent)
      has_ref:function(FsEvent):boolean, string
      send_buffer_size:function(FsEvent, size:integer):integer, string
      recv_buffer_size:function(FsEvent, size:integer):integer, string
      fileno:function(FsEvent):integer, string
      get_type:function(FsEvent):string, integer

      start:function(FsEvent, path:string, flags:any, callback:function()):integer, string
      stop:function(FsEvent):integer, string
      getpath:function(FsEvent):string, string
   end

   new_fs_event:function():FsEvent

   record us_fs_poll_t
      -- Handle functions
      is_active:function(us_fs_poll_t):boolean, string
      is_closing:function(us_fs_poll_t):boolean, string
      close:function(us_fs_poll_t, callback:function())
      ref:function(us_fs_poll_t)
      unref:function(us_fs_poll_t)
      has_ref:function(us_fs_poll_t):boolean, string
      send_buffer_size:function(us_fs_poll_t, size:integer):integer, string
      recv_buffer_size:function(us_fs_poll_t, size:integer):integer, string
      fileno:function(us_fs_poll_t):integer, string
      get_type:function(us_fs_poll_t):string, integer

      start:function(us_fs_poll_t, path:string, interval:integer, callback:function()):integer, string
      stop:function(us_fs_poll_t):integer, string
      getpath:function(us_fs_poll_t):string, string
   end

   new_fs_poll:function():us_fs_poll_t, string

   record fs_stats_t
      record TimeInfo
         sec:integer
         nsec:integer
      end

      dev:integer
      mode:integer
      nlink:integer
      uid:integer
      gid:integer
      rdev:integer
      ino:integer
      size:integer
      blksize:integer
      blocks:integer
      flags:integer
      gen:integer
      atime:TimeInfo
      mtime:TimeInfo
      ctime:TimeInfo
      birthtime:TimeInfo
      type:string
   end

   record Fs
   end

   fs_close:function(fd:integer):boolean, string
   fs_close:function(fd:integer, callback:function()):Fs

   fs_open:function(path:string, flags:string|integer, mode:integer):integer, string
   fs_open:function(path:string, flags:string|integer, mode:integer, callback:function()):Fs

   fs_read:function(fd:integer, size:integer, offset:integer):string, string
   fs_read:function(fd:integer, size:integer, offset:integer, callback:function()):Fs

   fs_unlink:function(path:string):boolean, string
   fs_unlink:function(path:string, callback:function()):Fs

   fs_write:function(fd:integer, data:any, offset:integer):integer, string
   fs_write:function(fd:integer, data:any, offset:integer, callback:function()):Fs

   fs_mkdir:function(path:string, mode:integer):boolean, string
   fs_mkdir:function(path:string, mode:integer, callback:function()):Fs

   fs_mkdtemp:function(template:string):string, string
   fs_mkdtemp:function(template:string, callback:function()):Fs

   fs_mkstemp:function(template:string):integer | string, string
   fs_mkstemp:function(template:string, callback:function()):Fs

   fs_rmdir:function(path:string):boolean, string
   fs_rmdir:function(path:string, callback:function()):Fs

   fs_scandir:function(path:string, callback:function()):Fs, string
   fs_scandir_next:function(fs:Fs):string, string

   fs_stat:function(path:string):fs_stats_t
   fs_stat:function(path:string, callback:function()):Fs

   fs_fstat:function(fd:integer):any, string
   fs_fstat:function(fd:integer, callback:function()):Fs

   fs_lstat:function(path:string):any, string
   fs_lstat:function(path:string, callback:function()):Fs

   fs_rename:function(path:string, new_path:string):boolean, string
   fs_rename:function(path:string, new_path:string, callback:function()):Fs

   fs_fsync:function(fd:integer):boolean, string
   fs_fsync:function(fd:integer, callback:function()):Fs

   fs_fdatasync:function(fd:integer):boolean, string
   fs_fdatasync:function(fd:integer, callback:function()):Fs

   fs_ftruncate:function(fd:integer, offset:integer):boolean, string
   fs_ftruncate:function(fd:integer, offset:integer, callback:function()):Fs

   fs_sendfile:function(out_fd:integer, in_fd:integer, in_offset:integer, size:integer):integer, string
   fs_sendfile:function(out_fd:integer, in_fd:integer, in_offset:integer, size:integer, callback:function()):Fs

   fs_access:function(path:string, mode:integer):boolean, string
   fs_access:function(path:string, mode:integer, callback:function()):Fs

   fs_chmod:function(path:string, mode:integer):boolean, string
   fs_chmod:function(path:string, mode:integer, callback:function()):Fs

   fs_fchmod:function(fd:integer, mode:integer):boolean, string
   fs_fchmod:function(fd:integer, mode:integer, callback:function()):Fs

   fs_utime:function(path:string, atime:number, mtime:number):boolean, string
   fs_utime:function(path:string, atime:number, mtime:number, callback:function()):Fs

   fs_futime:function(fd:integer, atime:number, mtime:number):boolean, string
   fs_futime:function(fd:integer, atime:number, mtime:number, callback:function()):Fs

   fs_lutime:function(path:string, atime:number, mtime:number):boolean, string
   fs_lutime:function(path:string, atime:number, mtime:number, callback:function()):Fs

   fs_link:function(path:string, new_path:string):boolean, string
   fs_link:function(path:string, new_path:string, callback:function()):Fs

   fs_symlink:function(path:string, new_path:string, flags:any):boolean, string
   fs_symlink:function(path:string, new_path:string, flags:any, callback:function()):Fs

   fs_readlink:function(path:string):string, string
   fs_readlink:function(path:string, callback:function()):Fs

   fs_realpath:function(path:string):string, string
   fs_realpath:function(path:string, callback:function()):Fs

   fs_chown:function(path:string, uid:integer, gid:integer):boolean, string
   fs_chown:function(path:string, uid:integer, gid:integer, callback:function()):Fs

   fs_fchown:function(fd:integer, uid:integer, gid:integer):boolean, string
   fs_fchown:function(fd:integer, uid:integer, gid:integer, callback:function()):Fs

   fs_lchown:function(fd:integer, uid:integer, gid:integer):boolean, string
   fs_lchown:function(fd:integer, uid:integer, gid:integer, callback:function()):Fs

   fs_copyfile:function(path:string, new_path:string, flags:any):boolean, string
   fs_copyfile:function(path:string, new_path:string, flags:any, callback:function()):Fs

   record Ldir
      readdir:function(Ldir):any, string
      readdir:function(Ldir, callback:function()):Fs

      closedir:function(Ldir):any, string
      closedir:function(Ldir, callback:function()):Fs
   end

   fs_opendir:function(path:string, entries:integer):Ldir, string
   fs_opendir:function(path:string, callback:function(), entries:integer):Fs

   fs_statfs:function(path:string, callback:function()):any

   -- Thread pool stuff

   record LworkCtx
      queue:function(LworkCtx, ...:any):boolean, string
   end

   new_work:function(work_callback:function(), after_work_callback:function()):LworkCtx

   -- dns utility functions

   getaddrinfo:function(host:string, service:string, hints:any, callback:function())
   getnameinfo:function(address:any, callback:function())

   record Lthread
      equal:function(Lthread, other:Lthread):boolean
      setaffinity:function(Lthread, affinity:any, get_old_affinity:boolean)
      getaffinity:function(Lthread, mask_size:integer)
      join:function(Lthread)
   end

   new_thread:function(options:any, entry:function() | string, ...:any):Lthread, string
   thread_getcpu:function():integer, string
   thread_self:function():Lthread

   sleep:function(msec:integer)
   exepath:function():string
   cwd:function():string, string
   chdir:function(cwd:string):integer, string
   get_process_title:function():string, string
   set_process_title:function(string):integer, string
   get_total_memory:function():number
   get_free_memory:function():number
   get_constrained_memory:function():number
   get_available_memory:function():number
   resident_set_memory:function():integer, string
   getrusage:function():any
   available_parallelism:function():integer
   cpu_info:function():any
   cpumask_size:function():integer, string
   getuid:function():integer
   getgid:function():integer
   setuid:function(integer)
   setgid:function(integer)
   hrtime:function():number
   clock_gettime:function(clock_id:string):any
   uptime:function():number, string
   print_all_handles:function()
   print_active_handles:function()
   guess_handle:function(fd:integer):string
   gettimeofday:function():integer, (integer | string)
   interface_addresses:function():any
   if_indextoname:function(ifindex:integer):string, string
   if_indextoiid:function(ifindex:integer):string, string
   loadavg:function():number, number, number

   record UnameInfo
      sysname:string
      release:string
      version:string
      machine:string
   end

   os_uname:function():UnameInfo

   os_gethostname:function():string
   os_getenv:function(name:string, size:integer):string, string
   os_setenv:function(name:string, value:string):boolean, string
   os_unsetenv:function():boolean, string
   os_environ:function():{any}
   os_homedir:function():string, string
   os_tmpdir:function():string, string
   os_get_passwd:function():any
   os_getpid:function():integer
   os_getppid:function():integer
   os_getpriority:function(pid:integer):integer, string
   os_setpriority:function(pid:integer, priority:integer):boolean, string
   random:function(len:integer, flags:any, callback:function()):string | integer, string
   translate_sys_error:function(errcode:integer):string, string
   metrics_idle_time:function():number
   metrics_info:function():any
end

return uv
