require 'net/http'
require 'json'
require 'uri'

SUCCESS = 'Successful'
FAILED = 'Failed'

def get_url(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  return JSON.parse(response.body)
end

def calculate_health(successful_count, count)
  return (successful_count / count.to_f * 100).round
end

def get_build_health(build)
  if build['server'] == 'Bamboo' then
    return get_bamboo_build_health build['id']
  elsif build['server'] == 'Travis' then
    return get_travis_build_health build['id']
  end
end

def get_travis_build_health(build_id)
  url = "https://api.travis-ci.org/repos/#{build_id}/builds?event_type=push"
  results = get_url url
  successful_count = results.count { |result| result['result'] == 0 }
  latest_build = results[0]

  return {
    name: build_id,
    status: latest_build['result'] == 0 ? SUCCESS : FAILED,
    duration: latest_build['duration'],
    link: "https://travis-ci.org/#{build_id}/builds/#{latest_build['id']}",
    health: calculate_health(successful_count, results.count),
    time: latest_build['started_at']
  }
end

def get_bamboo_build_health(build_id)
  url = "#{Builds::BUILD_CONFIG['bambooBaseUrl']}/rest/api/latest/result/#{build_id}.json?expand=results.result"
  build_info = get_url url

  results = build_info['results']['result']
  successful_count = results.count { |result| result['state'] == 'Successful' }
  latest_build = results[0]

  return {
    name: latest_build['plan']['shortName'],
    status: latest_build['state'] == 'Successful' ? SUCCESS : FAILED,
    duration: latest_build['buildDurationDescription'],
    link: Builds::BUILD_CONFIG['bambooBaseUrl'] + 'browse/' + latest_build['key'],
    health: calculate_health(successful_count, results.count),
    time: latest_build['buildRelativeTime']
  }
end

SCHEDULER.every '10s' do
  Builds::BUILD_LIST.each do |build|
    send_event(build['id'], get_build_health(build))
  end
end