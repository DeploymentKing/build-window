SUCCESS = 'Successful'.freeze
FAILED = 'Failed'.freeze

def api_functions
  {
    'Travis' => ->(build_id) { get_travis_build_health build_id },
    'TeamCity' => ->(build_id) { get_teamcity_build_health build_id },
    'Bamboo' => ->(build_id) { get_bamboo_build_health build_id },
    'Go' => ->(build_id) { get_go_build_health build_id },
    'Jenkins' => ->(build_id) { get_jenkins_build_health build_id }
  }
end

def get_url(url, auth = nil)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  request = Net::HTTP::Get.new(uri.request_uri)

  request.basic_auth(*auth) unless auth.nil?

  response = http.request(request)
  JSON.parse(response.body)
end

def calculate_health(successful_count, count)
  (successful_count / count.to_f * 100).round
end

def get_build_health(build)
  api_functions[build['server']].call(build['id'])
end

def get_teamcity_build_health(build_id)
  builds = TeamCity.builds(count: 25, buildType: build_id)
  latest_build = TeamCity.build(id: builds.first['id'])
  successful_count = builds.count { |build| build['status'] == 'SUCCESS' }

  {
    name: latest_build['buildType']['name'],
    status: latest_build['status'] == 'SUCCESS' ? SUCCESS : FAILED,
    link: builds.first['webUrl'],
    health: calculate_health(successful_count, builds.count)
  }
end

def get_travis_build_health(build_id)
  url = "https://api.travis-ci.org/repos/#{build_id}/builds?event_type=push"
  results = get_url url
  successful_count = results.count { |result| (result['result']).zero? }
  latest_build = results[0]

  {
    name: build_id,
    status: (latest_build['result']).zero? ? SUCCESS : FAILED,
    duration: latest_build['duration'],
    link: "https://travis-ci.org/#{build_id}/builds/#{latest_build['id']}",
    health: calculate_health(successful_count, results.count),
    time: latest_build['started_at']
  }
end

def get_go_pipeline_status(pipeline)
  pipeline['stages'].index { |s| s['result'] == 'Failed' }.nil? ? SUCCESS : FAILED
end

def get_go_build_health(build_id)
  url = "#{Builds::BUILD_CONFIG['goBaseUrl']}/go/api/pipelines/#{build_id}/history"

  auth = ENV['GO_USER'].nil? ? nil : [ENV['GO_USER'], ENV['GO_PASSWORD']]

  build_info = get_url url, auth

  results = build_info['pipelines']
  successful_count = results.count { |result| get_go_pipeline_status(result) == SUCCESS }
  latest_pipeline = results[0]

  {
    name: latest_pipeline['name'],
    status: get_go_pipeline_status(latest_pipeline),
    link: "#{Builds::BUILD_CONFIG['goBaseUrl']}/go/tab/pipeline/history/#{build_id}",
    health: calculate_health(successful_count, results.count)
  }
end

def get_bamboo_build_health(build_id)
  url = "#{Builds::BUILD_CONFIG['bambooBaseUrl']}/rest/api/latest/result/#{build_id}.json?expand=results.result"
  build_info = get_url url

  results = build_info['results']['result']
  successful_count = results.count { |result| result['state'] == 'Successful' }
  latest_build = results[0]

  {
    name: latest_build['plan']['shortName'],
    status: latest_build['state'] == 'Successful' ? SUCCESS : FAILED,
    duration: latest_build['buildDurationDescription'],
    link: "#{Builds::BUILD_CONFIG['bambooBaseUrl']}/browse/#{latest_build['key']}",
    health: calculate_health(successful_count, results.count),
    time: latest_build['buildRelativeTime']
  }
end

def get_jenkins_build_health(build_id)
  url = "#{ENV['JENKINS_URL']}/job/#{build_id}/api/json?tree=builds[status,timestamp,id,result,duration,url,fullDisplayName]"

  auth = ENV['JENKINS_USER'].nil? ? nil : [ENV['JENKINS_USER'], ENV['JENKINS_TOKEN']]

  build_info = get_url URI.encode(url), auth
  builds = build_info['builds']
  builds_with_status = builds.reject { |build| build['result'].nil? }
  successful_count = builds_with_status.count { |build| build['result'] == 'SUCCESS' }
  latest_build = builds_with_status.first
  {
    name: latest_build['fullDisplayName'],
    status: latest_build['result'] == 'SUCCESS' ? SUCCESS : FAILED,
    duration: latest_build['duration'] / 1000,
    link: latest_build['url'],
    health: calculate_health(successful_count, builds_with_status.count),
    time: latest_build['timestamp']
  }
end

SCHEDULER.every '20s' do
  Builds::BUILD_LIST.each do |build|
    send_event(build['id'], get_build_health(build))
  end
end
