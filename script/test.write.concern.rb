require 'net/http'
url = "http://localhost:3000/v2/track_activity?client_id=5511e3626762727d77000000&apikey=ba331a299b18a7133529806bb8456351b164199894ba4d6f2d09b1650e33cbc8&user_id=last&activity=browse"
start = Time.now

100.times do
  Net::HTTP.get_response(URI(url))
  print '.'
end

puts Time.now - start
