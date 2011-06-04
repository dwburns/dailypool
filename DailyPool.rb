require 'net/http'
require 'uri'
require 'rexml/document'
require 'logger'
require 'digest/md5'

@@baseUrl='http://api.flickr.com/services/rest/'
@@apiKey="YOUR_API_KEY"
@@apiSecret="YOUR_API_SECRET"
@@token="YOUR_TOKEN"
@@maxPhotos=250

@@logger = Logger.new('YOUR_LOG_PATH/log.txt')
@@logger.level = Logger::DEBUG

@@queue = [];

def request(inUrl)
  # wait before making a request
  seconds = rand(4) + 1
  @@logger.debug "Waiting #{seconds} second(s) before sending request."
  sleep(seconds)
  
  @@logger.debug "Sending request to #{inUrl}"
  url = URI.parse(inUrl)
  request = Net::HTTP::Get.new(url.path + '?' + url.query)
  response = Net::HTTP.start(url.host,url.port) do |http|
    http.request(request)
  end
  return response
end

def sign(params)
  out = @@apiSecret
  params.keys.sort.each do |key|
    out = out + key + params[key]
  end
  return Digest::MD5.hexdigest(out)
end

def buildUrl(params)
  out = @@baseUrl + '?'
  params.keys.each do |key|
    out = out + key + '=' + params[key] + '&'
  end
  return out;
end

# Get 500 photos from interestingness
@@logger.info "Getting photos from interestingness"

params = {
  'method' => 'flickr.interestingness.getList',
  'api_key' => @@apiKey,
  'per_page' => '500'
}
url = buildUrl(params)
response = request(url)
xml = REXML::Document.new response.body
photos = REXML::XPath.match(xml, "//photo")

# Build a queue of photos that are of the correct size and license
@@logger.info "Finding photos with the correct size and license."

photos.each do |photo|
  if(photo.attributes['ispublic'] != 0)
    # Get license info
    params = {
      'method' => 'flickr.photos.getInfo',
      'photo_id' => photo.attributes['id'],
      'api_key' => @@apiKey
    }
    url = buildUrl(params)
    response = request(url)
    xml = REXML::Document.new response.body
    info = REXML::XPath.match(xml, "/rsp/photo")
    if(info)
      if(info[0].attributes['license'].to_i > 0)
        # Get sizes
        params = {
          'method' => 'flickr.photos.getSizes',
          'api_key' => @@apiKey,
          'photo_id' => photo.attributes['id']
        }
        url = buildUrl(params)
        response = request(url)
        xml = REXML::Document.new response.body
        sizes = REXML::XPath.match(xml,'//size')
        use = nil
        sizes.reverse.each do |size|
          use = size.attributes['source'] if ['Original','Large'].include?(size.attributes['label'])
        end
        if use
          @@queue.push(photo.attributes['id'])
          @@logger.debug("Adding photo #{photo.attributes['id']} to queue.")
        end
      end
    end
  end
end
@@logger.info "Found #{@@queue.length} photos."

# Delete favorites to make room
@@logger.info "Deleting old favorites to make room"

@@logger.info "Getting list of favorites."
params = {
  'method' => 'flickr.favorites.getList',
  'per_page' => '500',
  'api_key' => @@apiKey,
  'auth_token' => @@token
}
params['api_sig'] = sign(params);
url = buildUrl(params)
response = request(url)
xml = REXML::Document.new response.body
photos = REXML::XPath.match(xml, "//photo")

# if existing photos plus new photos are greater than max photos then we need to delete some
if((photos.length + @@queue.length) > @@maxPhotos)
  removeCount = (photos.length + @@queue.length) - @@maxPhotos
  removeStart = @@maxPhotos - removeCount - 1
  removeEnd = removeStart + removeCount - 1 # remove 1 for array indexing
  @@logger.info("Removing #{removeCount} photos from favorites to make room.")
  removePhotos = photos.slice(removeStart, removeEnd)
  if(removePhotos)
    removePhotos.each do |photo|
      params = {
        'method' => 'flickr.favorites.remove',
        'api_key' => @@apiKey,
        'auth_token' => @@token,
        'photo_id' => photo.attributes['id']
      }
      params['api_sig'] = sign(params)
      url = buildUrl(params)
      @@logger.debug "Attempting to remove photo #{photo.attributes['id']} via URL #{url}"
      request(url)
    end
  end
end

# Favorite every photo in the queue
@@logger.info "Adding #{@@queue.size} photos to favorites"

count = 1
@@queue.each do |id|
  params = {
    'method' => 'flickr.favorites.add',
    'api_key' => @@apiKey,
    'auth_token' => @@token,
    'photo_id' => id
  }
  params['api_sig'] = sign(params)
  url = buildUrl(params)
  request(url)
  count = count + 1
  @@logger.debug "Adding favorite #{id} (#{count} of #{@@queue.size})."
end