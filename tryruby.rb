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

rendezvous = Rendezvous.new(url: data['rendezvous_url'],
                            input: $stdin,
                            output: $stdout)

Rendezvous.start(
  :url => data['rendezvous_url']
)
