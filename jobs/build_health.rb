SUCCESS = 'Successful'.freeze
FAILED = 'Failed'.freeze
UNKNOWN = 'No Builds'.freeze

def get_url(url, auth)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  request = Net::HTTP::Get.new(uri.request_uri)

  request.basic_auth(*auth)

  response = http.request(request)
  JSON.parse(response.body)
end

def get_jenkins_build_health(job)
  url = "#{job['server_url']}/job/#{job['id']}/api/json?tree=builds[status,timestamp,id,result,duration,url,fullDisplayName]"

  build_info = get_url url, [job['user'], job['token']]
  builds = build_info['builds']
  if builds.empty?
    {
      name: job['id'].gsub('/job/', ' » ').gsub('%252F', '/').camelize,
      status: UNKNOWN,
      duration: 0,
      link: url,
      health: 0,
      time: Time.now.getutc.to_i
    }
  else
    builds_with_status = builds.reject { |build| build['result'].nil? }
    successful_count = builds_with_status.count { |build| build['result'] == 'SUCCESS' }
    latest_build = builds_with_status.first unless builds_with_status.nil? || builds_with_status.empty?
    {
      name: latest_build['fullDisplayName'],
      status: latest_build['result'] == 'SUCCESS' ? SUCCESS : FAILED,
      duration: latest_build['duration'] / 1000,
      link: latest_build['url'],
      health: (successful_count / builds_with_status.count.to_f * 100).round,
      time: latest_build['timestamp']
    }
  end

end

SCHEDULER.every '20s' do
  puts 'get build health'
  Builds.get.each do |job|
    send_event(job['id'], get_jenkins_build_health(job))
  end
end

SCHEDULER.every '60s' do
  puts 'reset jobs list'
  Builds.reset
end
