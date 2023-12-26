# we currently use 2 slack gems
# gem 'slack-notifier'
# gem 'slack-ruby-client' # official gems

# 'slack-notifier' will mostly used for ExceptionNotification and on iphone side
# 'slack-ruby-client' this have complete api
Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end