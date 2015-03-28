require 'sinatra'
require 'json'

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
    puts payload[event_info['event']]['title']
    puts payload[event_info['event']]['body']
  end

  def github_event(payload)
    # Normally the GitHub event is present in the X-GitHub-Event headers but sometimes
    # that header is absent in which case we need to brute force it.

# {"action"=>"opened", "number"=>1, "pull_request"
    events = %w(commit_comment create delete deployment deployment_status fork gollum issue_comment issues pull_request)

    event = (payload.keys & events).first # should only ever be one

    {'action' => payload['action'], 'event' => event}
  end
end
