require 'timeout'
require 'stringio'
require_relative "lib/spawner"

s = Spawner.from_environment
s.spawn("bash") do |read, write|
  pid = fork do
    write.close
    until read.eof?
      print read.readpartial(4096)
    end
  end

  write.write("exit\n")
  
  Process.wait(pid)
end
