# cms.rb
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

# Enables sessions
configure do
  enable :sessions
  set :session_secret, 'super secret'
end

# Renders the home page
get "/" do
  @files = fetch_files
  erb :index
end

# Renders the sign in form
get "/users/signin" do
  erb :sign_in
end

# Renders the "new doc" page for creating new files
get "/new" do
  require_signed_in
  erb :new_doc
end

# Renders content for a particular file
get "/:filename" do | filename |
  file = full_path(filename)
  if File.exist?(file)
    load_file_content(file)
  else
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end
end

# Renders the "edit" page for a particular file.
get "/:filename/edit" do | filename |
  file = full_path(filename)
  require_signed_in
  if File.exists?(file)
    @filename = filename
    @content = File.read(file)
    erb :edit
  else
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end
end

# Signs a user in
post "/users/signin" do
  if valid_credentials?(params[:username], params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:message] = "Invalid credentials!"
    erb :sign_in
  end
end

# Signs a user out.
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

# Deletes a file
post "/:filename/delete" do |filename|
  require_signed_in
  file_path = File.join(data_path, filename)
  File.delete(file_path)
  session[:message] = "#{filename} has been successfully deleted."
  redirect "/"
end

# Creates a new file
post "/create" do
  require_signed_in
  filename = params[:filename].to_s
  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new_doc
  elsif no_extension?(filename)
    session[:message] = "A file extension (.doc, .txt, etc.) is required."
    status 422
    erb :new_doc
  else
    file_path = File.join(data_path, filename)
    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been successfully created."
    redirect "/"
  end
end

# Updates an existing file.
post "/:filename" do |filename|
  require_signed_in
  File.write(full_path(filename), params[:content])

  session[:message] = "#{filename} has been successfully updated!"
  redirect "/"
end

# Redirects if user isn't signed in.
def require_signed_in
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# Returns true if a user is signed in, else false
def signed_in?
  session.key?(:username)
end

# Returns true if the filename has an extension, else false
def no_extension?(filename)
  File.extname(filename) == ""
end

# Generates the absolute data path.
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# Converts basename to full path
def full_path(filename)
  File.join(data_path, filename)
end

# Fetches and returns all filenames under the "data" directory
def fetch_files
  Dir.glob(File.join(data_path, "*")).map do |path|
    File.basename(path)
  end
end

# Converts markdown to text
def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

# Loads file content, specific to file extension
def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

# Checks if the login credentials are valid
def valid_credentials?(username, password)
  creds = load_creds
  if creds.key?(username)
    hsh_pw = BCrypt::Password.new(creds[username])
    hsh_pw == password
  else
    false
  end
end


def load_creds
  cred_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(cred_path)
end