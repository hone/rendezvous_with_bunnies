require 'heroku-api'
require 'rendezvous'

heroku = Heroku::API.new(:api_key => ENV['HEROKU_API_KEY'])
env = { 'TERM' => ENV['TERM'] }
begin
  env['COLUMNS']  = `tput cols`.strip
  env['LINES']    = `tput lines`.strip
rescue StandardError => e
  $stderr.puts e
end

data = heroku.post_ps(
  ENV['HEROKU_APP'],
  'bash',
  { :attach => true, :ps_env => env }
).body

parent_read, child_write = IO.pipe
child_read, parent_write = IO.pipe

rendezvous = Rendezvous.new(url:    data['rendezvous_url'],
                            input:  child_read,
                            output: child_write)

child_pid = fork do
  parent_read.close
  parent_write.close
  rendezvous.start
end

read_pid = fork do
  parent_write.close
  until parent_read.eof?
    print parent_read.readpartial(4096)
  end
end

parent_write.write("ls\n")
parent_write.write("exit\n")

Process.wait(read_pid)

parent_read.close
parent_write.close

Process.wait(child_pid)
