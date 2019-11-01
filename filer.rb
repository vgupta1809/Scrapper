require 'csv'

data = []
uniq_urls = []
website_urls = []
table = CSV.read('yelp_tallahassee.csv')

table[1..-1].each do |t|
  uri = URI.parse(t.last)
  uri.query = nil
  uri.fragment = nil
  next if uniq_urls.include?(uri.to_s)
    uniq_urls << uri.to_s
    website = t[7]
  unless website_urls.include?(website)
    website_urls << website
  else
    website = nil
  end
  row = t[0..6] + [website.to_s] + t[8..9] + [uri.to_s]
  data << row
end
header  = %w[Name Phone Address City State ZipCode neighborhood website reviews rating Yelp_url]
data.insert(0,header)
File.open('yelp_tallahassee_info.csv', 'w') do |f|
 f.write(data.map(&:to_csv).join())
end


