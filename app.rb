require 'sinatra'
require 'rest-client'
require 'time'
require 'hnrb'
require_relative './1self_hackernews'

CALLBACK_BASE_URI = ENV['CALLBACK_BASE_URI'] || 'http://localhost:4567'
API_BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:5000'

configure do
  enable :sessions, :logging
  set :logging, true
  set :session_secret, 'dqgAkAzrmpjt6XVxEAxkk3HKpMJdZsrn'
  set :views, "#{File.dirname(__FILE__)}/views"
  set :public_folder, proc { File.join(root, 'public') }
end

get '/' do
  session['registrationToken'] = params[:token]
  erb :index
end

post '/accept' do
  hn_username = params[:hn_username]
  callback_url = "#{CALLBACK_BASE_URI}/sync?hn_username=#{hn_username}&latestSyncField={{latestSyncField}}&streamid={{streamid}}"

  stream_resp = HackerNews1SelfLib.register_stream(hn_username, session['registrationToken'], callback_url)
  stream = JSON.parse(stream_resp)
  puts 'Registered stream'

  karmas = HackerNews1SelfLib.fetch_karma(hn_username)
  puts 'Fetched karmas'

  oneself_events = HackerNews1SelfLib.convert_to_1self_events(karmas)
  puts 'Converted to 1self events'

  HackerNews1SelfLib.send_to_1self(stream['streamid'], stream['writeToken'], oneself_events)
  redirect(API_BASE_URL + '/integrations')
end

get '/sync' do
  latest_sync_field = params[:latestSyncField]
  streamid = params[:streamid]
  # username = params[:username]
  hn_username = params[:hn_username]
  write_token = request.env['HTTP_AUTHORIZATION']

  karmas = HackerNews1SelfLib.fetch_karma(hn_username, latest_sync_field)
  puts 'Fetched karmas'

  oneself_events = HackerNews1SelfLib.convert_to_1self_events(karmas)
  puts 'Converted to 1self events'

  HackerNews1SelfLib.send_to_1self(streamid, write_token, oneself_events)
  puts 'Sent to 1self'
  'Success'
end
