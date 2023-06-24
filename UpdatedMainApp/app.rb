require 'sinatra'
require 'sinatra/reloader' if development? # Learn more about the reloader at sinatrarb.com
require 'sinatra/multi_route'
require 'pstore'

def store
  @store ||= PStore.new("url_store.db")
end

set :public_folder, Proc.new { File.join(root, "public") }

get '/','/home' do
    erb :home
  end

get '/about' do
  erb :about
end

get '/contact' do
  erb :contact
end

# This page gets rendered when the user enters an unidentified route
not_found do
  erb :not_found, :layout => :error_layout
end

# Route for shortening URL
get '/shorten' do
  long_url = params[:url]
  desired_length = params[:length].to_i
  puts "Long URL: #{long_url}"
  puts "Desired Length: #{desired_length}"
  short_url = generate_short_url(long_url, desired_length)
  error_message = nil
  if short_url
    full_short_url = "#{request.base_url}/#{short_url}"
  else
    error_message = "Error: Unable to generate a unique short URL. Please try again later or increase the URL length."
  end

  erb :shortened, locals: { short_url: full_short_url, error_message: error_message }
end


# Route for redirecting to long URL
get '/:short_url' do
  short_url = params[:short_url]
  long_url = get_long_url(short_url)
  puts "Long URL: #{long_url}"
  
  if long_url
    redirect "https://" + long_url
  else
    "Short URL not found"
  end
end

# Generate short URL
def generate_short_url(long_url,desired_length)
  short_url = find_existing_short_url(long_url)
  attempts = 0
  max_attempts = 20
  if short_url.nil?
    loop do
      short_url = generate_random_string(desired_length,desired_length)
      break unless short_url_exists?(short_url)
      attempts += 1
      if attempts >= max_attempts
        short_url = nil
        break
      end
    end

    save_short_url(short_url, long_url)
  end

  short_url
end

# Find existing short URL for the given long URL
def find_existing_short_url(long_url)
  existing_short_url = nil

  store.transaction(true) do
    store.roots.each do |short_url|
      if store[short_url] == long_url
        existing_short_url = short_url
        break
      end
    end
  end

  existing_short_url
end


# Generate random string
def generate_random_string(min_len, max_len)
  alphabet = ('a'..'z').to_a + ('0'..'9').to_a
  len = rand(min_len..max_len)

  (0...len).map { alphabet.sample }.join
end

# Check if short URL already exists in PStore
def short_url_exists?(short_url)
  exists = false

  store.transaction(true) do
    exists = store.root?(short_url)
  end

  exists
end

# Save short URL to PStore
def save_short_url(short_url, long_url)
  store.transaction do
    store[short_url] = long_url
  end
end

# Get long URL from PStore
def get_long_url(short_url)
  long_url = nil

  store.transaction(true) do
    long_url = store[short_url] if store.root?(short_url)
  end

  long_url
end

