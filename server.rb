require 'sinatra'
require 'json'
require 'octokit'
require 'yaml'
require 'byebug'

# TODO: Can't get it working with Oauth2 (client_id and client_secret)
#       But works great for Oauth (access_token)
oauth_config = YAML.load_file("oauth.yml")
CLIENT_ID = oauth_config['client_id']
CLIENT_SECRET = oauth_config['client_secret']
GITHUB = Octokit::Client.new({
  client_id: CLIENT_ID,
  client_secret: CLIENT_SECRET
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

class PullRequestHandler
  def initialize(payload)
    @payload = payload
  end

  def handle
    title = @payload['pull_request']['title']
    description = @payload['pull_request']['body']

    repo = @payload['pull_request']['head']['repo']
    owner = repo['owner']['login']
    name = repo['name']
    number = @payload['number']

    unless /MCC\-(\d)+ /.match(title)
      puts "Please put the MCC number in the Pull Request!"
      GITHUB.post("/repos/#{owner}/#{name}/issues/#{number}/comments", {
        body: 'Please put the MCC number in the Pull Request'
      })
    end

    unless description
      puts "Please put provide a description to your Pull Request!"
    end
  end
end
