require 'sinatra'
require 'rest-client'
require 'json'
require 'slack-notifier'
require 'jenkins_api_client'

get '/' do
  "This is a thing"
end

post '/' do

  # Verify all environment variables are set
  return [403, "No slack token setup"] unless slack_token = ENV['SLACK_TOKEN']
  return [403, "No jenkins url setup"] unless jenkins_url= ENV['JENKINS_URL']
  return [403, "No jenkins username setup"] unless jenkins_username= ENV['JENKINS_USERNAME']
  return [403, "No jenkins token setup"] unless jenkins_token= ENV['JENKINS_TOKEN']

  # Verify slack token matches environment variable
  return [401, "No authorized for this command"] unless slack_token == params['token']

  @jenkins_client = JenkinsApi::Client.new(
      # :server_ip => jenkins_ip,
      :server_url => jenkins_url,
      :username => jenkins_username,
      :password => jenkins_token,
      :log_level => Logger::DEBUG,
      :follow_redirects => true,
      )

  # Split command text
  text_parts = params['text'].split(' ')

  # Split command text - job_name
  job_name = text_parts[0]

  # Split command text - job_params
  job_params = {}
  if text_parts.size > 1
    all_params = text_parts[1..-1]
    all_params.each do |p|
      p_thing = p.split('=')
      job_params << { :name => p_thing[0], :value => p_thing[1] }
    end
  end

  # Jenkins url
  jenkins_job_url = "#{jenkins_url}/job/#{job_name}"

  # Wait for up to 30 seconds, attempt to cancel queued build, progress
  opts = {'build_start_timeout' => 30,
          'cancel_on_build_start_timeout' => true,
          'poll_interval' => 2,      # 2 is actually the default :)
          'progress_proc' => lambda {|max,curr,count| puts "max #{max}, curr #{curr}, count #{count}" },
          'completion_proc' => lambda {|build_number,cancelled| 
              # slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
              if slack_webhook_url
                notifier = Slack::Notifier.new slack_webhook_url
                notifier.ping "Started job '#{job_name}' - #{jenkins_job_url}/#{build_number}"
              end
           }}
  @client.job.build(job_name, job_params, opts)

  job_name

end
