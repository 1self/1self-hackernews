# Foursquare 1self lib

module HackerNews1SelfLib

  extend self

  APP_ID = ENV['APP_ID'] || 'app-id-hn223f557f9cdf57e136dd719c697aea'
  APP_SECRET = ENV['APP_SECRET'] || 'app-secret-hn0c132e478ca4bd35c87704ca1016d59d8235ef6172d0b507e4c40f5f04503a'
  API_BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:5000'

  def register_stream(oneself_username, registration_token, callback_url)
    headers =  {Authorization: "#{APP_ID}:#{APP_SECRET}", 'registration-token' => registration_token,
                'content-type' => 'application/json'}

    response =  RestClient::Request.execute( 
      method: :post,
      payload: {:callbackUrl => callback_url}.to_json,
      url: "#{API_BASE_URL}/v1/users/#{oneself_username}/streams",
      headers: headers,
      accept: :json
    )
    response
  end

  def fetch_karma(hn_username, afterTimestamp=nil)
    offset = 0
    hn = HNrb::APIWrapper.new    
    user = hn.get_user(hn_username)
    user.karma
  end

  def convert_to_1self_events(karma)
    oneself_events = []
    event = {
      source: '1self-hackernews',
      version: '0.0.1',
      objectTags: ['internet', 'social-network', 'hackernews'],
      actionTags: ['karma', 'reputation', 'sample'],
      properties: {},
      dateTime: Time.now.utc.iso8601,
      latestSyncField: Time.now.utc.to_i
    }

    data = {}
    data[:dateTime] =  Time.now.utc.iso8601
    data[:latestSyncField] = Time.now.utc.to_i
    data[:properties] = {}
    data[:properties][:source] = "1self-hackernews"
    data[:properties][:points] = karma

    oneself_events << event.merge(data)
    oneself_events
  end

  def send_to_1self(streamid, writeToken, oneself_events)
    url = API_BASE_URL + '/v1/streams/' + streamid + '/events/batch'
    puts("Authorization header is ", writeToken)
    request = lambda { |evts|  RestClient.post url, evts.to_json, content_type: :json, accept: :json, Authorization: writeToken }
    request.call(create_sync_start_event)

    sliced_oneself_events = oneself_events.each_slice(200).to_a
    sliced_oneself_events.each do |events|
      response = request.call(events)
    end
    request.call(create_sync_complete_event)
  end

  def create_sync_start_event
    [
      { dateTime: Time.now.utc.iso8601,
        objectTags: ['sync'],
        actionTags: ['start'],
        properties: {
          source: '1self-hackernews'
        }
      }]
  end

  def create_sync_complete_event
    [
      { dateTime:  Time.now.utc.iso8601,
        objectTags: ['sync'],
        actionTags: ['complete'],
        properties: {
          source: '1self-hackernews'
        }
      }]
  end

end
