This is a script I created a few years back to use Flickr Interestingness as my Apple TV Screen saver. I don't use Apple TV, the Flickr API, or Ruby anymore, so I can't really offer any support, but I'm offering the code up for anyone who's interested.

To use it, customize these values with your Flickr API Credentials and local logging path:

@@apiKey="YOUR_API_KEY"
@@apiSecret="YOUR_API_SECRET"
@@token="YOUR_TOKEN"

@@logger = Logger.new('YOUR_LOG_PATH/log.txt')

Then run:

ruby DailyPool.rb