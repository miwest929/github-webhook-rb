require 'sinatra'
require 'json'
require 'octokit'
require 'yaml'
require 'byebug'

# ngrok 4567

# TODO: Can't get it working with Oauth2 (client_id and client_secret)
#       But works great for Oauth (access_token)
oauth_config = YAML.load_file("oauth.yml")
ACCESS_TOKEN = oauth_config['gumby_access_token']
#CLIENT_ID = oauth_config['client_id']
#CLIENT_SECRET = oauth_config['client_secret']
GITHUB = Octokit::Client.new({
  access_token: ACCESS_TOKEN
#  client_id: CLIENT_ID,
#  client_secret: CLIENT_SECRET
})

get '/callback' do
  puts "Callback route invoked"
end

post '/payload' do
  push = JSON.parse(request.body.read)

  GithubWebhook.new.receive(push)
  #puts "I got some JSON: #{push.inspect}"
end

class GithubWebhook
  def initialize
  end

  # payload must be a Hash
  def receive(payload)
    event_info = github_event(payload)

    puts "#{event_info['action']} #{event_info['event']}"
    if event_info['event'] == 'pull_request' &&
       (event_info['action'] == 'opened' || event_info['action'] == 'reopened')
      PullRequestHandler.new(payload).handle
    end
  end

  def github_event(payload)
    # Normally the GitHub event is present in the X-GitHub-Event headers but sometimes
    # that header is absent in which case we need to brute force it.

    events = %w(commit_comment create delete deployment deployment_status fork gollum issue_comment issues pull_request)

    event = (payload.keys & events).first # should only ever be one

    {'action' => payload['action'], 'event' => event}
  end
end

class BaseCheck
  def initialize(payload)
    @data = payload
  end

end

class TitleMissingMCCNumberCheck < BaseCheck
  def check
    title = @data['title']

    /MCC\-(\d)+ /.match(title)
  end

  def msg
    'Please put the MCC number in the Pull Request.'
  end
end

class DescriptionMissingCheck < BaseCheck
  def check
    description = @data['body']

    description && description != ""
  end

  def msg
    'Please add a description to your Pull Request.'
  end
end

class PullRequestHandler
  def initialize(payload)
    @payload = payload
  end

  def handle
    repo = @payload['pull_request']['head']['repo']
    owner = repo['owner']['login']
    name = repo['name']
    number = @payload['number']

    checks = [TitleMissingMCCNumberCheck, DescriptionMissingCheck]
    msgs = checks.map do |c|
      cond = c.new(@payload['pull_request'])

      cond.check ? nil : cond.msg
    end.compact
    msgs = msgs.map {|m| "  - #{m}"}

    pr_comment = "Please address the following:\n#{msgs.join("\n")}"
    puts pr_comment
    GITHUB.post("/repos/#{owner}/#{name}/issues/#{number}/comments", {
      body: pr_comment
    })
  end
end
