require 'sinatra'
require 'rest-client'
require 'time'
require 'hnrb'
require 'sinatra/flash'
require_relative './1self_hackernews'

CALLBACK_BASE_URI = ENV['CALLBACK_BASE_URI'] || 'http://localhost:4567'
API_BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:5000'

logger = Logger.new(STDOUT)

logger.info('CALLBACK_BASE_URI: ' + CALLBACK_BASE_URI)
logger.info('API_BASE_URL: ' + API_BASE_URL)

configure do
  enable :sessions, :logging
  register Sinatra::Flash
  set :logging, true
  set :session_secret, 'dqgAkAzrmpjt6XVxEAxkk3HKpMJdZsrn'
  set :views, "#{File.dirname(__FILE__)}/views"
  set :public_folder, proc { File.join(root, 'public') }
end

get '/' do
  session['registrationToken'] = params[:token]
  session['oneselfUsername'] = params[:username]
  @message = flash[:notice]
  erb :index
end

post '/accept' do
  hn_username = params[:hn_username]
  callback_url = "#{CALLBACK_BASE_URI}/sync?hn_username=#{hn_username}&latestSyncField={{latestSyncField}}&streamid={{streamid}}"

  begin
    karmas = HackerNews1SelfLib.fetch_karma(hn_username)
    puts 'Fetched karmas'
  rescue Exception => e
    flash[:notice] = "Invalid Hacker News Username"
    redirect back and return
  end

  stream_resp = HackerNews1SelfLib.register_stream(session['oneselfUsername'], session['registrationToken'], callback_url)
  stream = JSON.parse(stream_resp)
  puts 'Registered stream'

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
