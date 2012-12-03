require 'stringio'
require "heroku/api"
require "heroku/client/rendezvous"

class Spawner

  attr_reader :env, :options

  def self.from_environment
    new(ENV["SPAWN_ENV"], :heroku_app => ENV["HEROKU_APP"], :heroku_api_key => ENV["HEROKU_API_KEY"])
  end

  def initialize(env, options={})
    @env = env.to_s.strip == "" ? "local" : env
    @options = options
  end

  def spawn(command, &blk)
    send("spawn_#{env}", command, &blk)
  end

  def spawn_local(command)
    parent, child = IO.pipe

    pid = fork do
      parent.close

      if block_given?
        $stdout.reopen child
        $stderr.reopen child
      end

      exec command
    end

    Process.detach(pid) unless block_given?
    child.close

    if block_given?
      yield parent
    end
  end

  def spawn_heroku(command, &blk)
    parent_read, child_write = IO.pipe
    child_read, parent_write = IO.pipe

    pid = fork do
      parent_read.close
      parent_write.close
      heroku = Heroku::API.new
      ps = heroku.post_ps(options[:heroku_app], command, { :attach => true })
      if block_given?
        rendezvous = Heroku::Client::Rendezvous.new(
          :rendezvous_url => ps.body["rendezvous_url"],
          :connect_timeout => 120,
          :input => child_read,
          :output => child_write
        )
        rendezvous.start
      end
    end

    child_read.close
    child_write.close

    if block_given?
      yield parent_read, parent_write
      parent_read.close
      parent_write.close
    end

    Process.wait(pid)
  end

end
