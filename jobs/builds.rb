# The Builds class will extract all the builds to display on the dashboard
module Builds
  @builds = []

  def get_jenkins_jobs(parent_job_url)
    url = parent_job_url.nil? ? "#{ENV['JENKINS_URL']}/job/#{ENV['JENKINS_PROJECT']}/api/json" : "#{parent_job_url}api/json"

    unless ENV['JENKINS_USER'].nil?
      auth = [ENV['JENKINS_USER'], ENV['JENKINS_TOKEN']]
    end

    job_info = get_url URI.encode(url), auth
    jobs = job_info['jobs']

    if jobs.nil?
      # There are no more sub-jobs so we can extract the build information from here
      @builds << { 'id' => parent_job_url.gsub("#{ENV['JENKINS_URL']}/job/", ''), 'server' => 'Jenkins' }
    else
      jobs.each do |job|
        get_jenkins_jobs(job['url'])
      end
    end
  end
  module_function :get_jenkins_jobs

  get_jenkins_jobs(nil)

  BUILD_CONFIG = JSON.parse(File.read('config/builds.json'))
  BUILD_LIST = @builds
  BUILD_PROJECT = ENV['JENKINS_PROJECT'].to_s.camelize
end
