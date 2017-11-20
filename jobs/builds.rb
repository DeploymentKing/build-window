require 'ansible/vault'

# The Builds class will extract all the builds to display on the dashboard
module Builds
  @jobs = []

  def get_jenkins_jobs(server_url, project, user, token, parent_job_url)
    url = parent_job_url.nil? ? "#{server_url}/job/#{project}/api/json" : "#{parent_job_url}api/json"

    job_info = get_url url, [user, token]
    jobs = job_info['jobs']

    if jobs.nil?
      # There are no more sub-jobs so we can extract the build information from here
      @jobs << {
        'id' => parent_job_url.gsub("#{server_url}/job/", ''),
        'project' => project,
        'server_url' => server_url,
        'user' => user,
        'token' => token
      }
    else
      jobs.each do |job|
        get_jenkins_jobs(server_url, project, user, token, job['url'])
      end
    end
  end
  module_function :get_jenkins_jobs

  contents = Ansible::Vault.read(path: 'config/jenkins.json', password: ENV['VAULT_PASSWORD'])
  JENKINS_CONFIG = JSON.parse(contents)
  JENKINS_SERVERS = JENKINS_CONFIG['servers']

  JENKINS_SERVERS.each do |server|
    get_jenkins_jobs(server['url'], server['id'], server['user'], server['token'], nil)
  end

  JOB_LIST = @jobs
end
