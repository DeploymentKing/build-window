require 'ansible/vault'
require_relative 'build_health'

# The Builds class will extract all the builds to display on the dashboard
module Builds
  @@jobs = []

  def self.reset
    @@jobs = job_list
  end

  def self.get
    @@jobs
  end

  def get_jenkins_jobs(server_url, project, user, token, parent_job_url, job_list)
    url = parent_job_url.nil? ? "#{server_url}/job/#{project}/api/json" : "#{parent_job_url}api/json"

    job_info = get_url url, [user, token]
    jobs = job_info['jobs']

    if jobs.nil?
      # There are no more sub-jobs so we can extract the build information from here
      job_list << {
        'id' => parent_job_url.gsub("#{server_url}/job/", ''),
        'project' => project,
        'server_url' => server_url,
        'user' => user,
        'token' => token
      }
    else
      jobs.each do |job|
        get_jenkins_jobs(server_url, project, user, token, job['url'], job_list)
      end
    end
  end
  module_function :get_jenkins_jobs

  def job_list
    puts 'getting job list'
    jobs = []

    contents = Ansible::Vault.read(path: 'config/jenkins.json', password: ENV['VAULT_PASSWORD'])
    jenkins_config = JSON.parse(contents)
    jenkins_servers = jenkins_config['servers']

    jenkins_servers.each do |server|
      get_jenkins_jobs(server['url'], server['id'], server['user'], server['token'], nil, jobs)
    end

    # Return list of jobs
    jobs
  end
  module_function :job_list
end
