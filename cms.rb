require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

# Obtaining root path of files according to environment we are at: development or test
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# Checking if file exist before reading its content
def file_exist?(file_path)
  File.file?(file_path)
end

# Detecting the type of file before reading its content
def file_type(file_path)
  File.extname(file_path)
end

# Loading file content, according to fyle type
def load_file(file_path)
  file_content = File.read(file_path)

  case file_type(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    file_content
  when ".md"
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    erb markdown.render(file_content)
  end
end

# Check if user is signed in; checks if :username key exists in session hash
def signed_user?
  session.key?(:username)
end

# Handles the routes that require to be signed in
def required_to_be_signed
  unless signed_user?
    session[:msg] = "Sorry, you must be signed in to perform this action."
    redirect "/"
  end
end

# Load credentials file; uses separates paths for the file if test environment or production environment
def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

# ----- ROUTES

# View list of documents in CMS
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }

  erb :index
end

# View signin form
get "/users/signin" do
  erb :signin
end

# Signing in
post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:msg] = "Welcome!"
    redirect "/"
  else
    session[:msg] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

# Signing out
post "/users/signout" do
  session.delete(:username)
  session[:msg]= "You have been signed out."
  redirect "/"
end

# View create new file / document
get "/new" do
  required_to_be_signed

  erb :new
end

# Create new file / document
post "/create" do
  required_to_be_signed

  filename = params[:filename].to_s
  file_path = File.join(data_path, filename)

  if filename.size == 0 || File.extname(file_path).size == 0
    session[:msg] = "Sorry, you must enter a valid name and extension."
    status 422
    erb :new
  else
    File.write(file_path, "")
    session[:msg] = "#{filename} has been created."

    redirect "/"
  end
end

# View content of each file
get "/:filename" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  if file_exist?(file_path)
    load_file(file_path)
  else
    session[:msg] = "Sorry, #{file_name} does not exist."
    redirect "/"
  end
end

# View edit a file page form
get "/:filename/edit" do
  required_to_be_signed

  @file_name = params[:filename]
  file_path = File.join(data_path, @file_name)
  @content = File.read(file_path)

  erb :edit
end

# Edit page
post "/:filename" do
  required_to_be_signed

  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  changes = params[:changes]

  File.write(file_path, changes)

  session[:msg] = "#{file_name} has been updated"
  redirect "/"
end

# View delete file form
post "/:filename/delete" do
  required_to_be_signed

  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  File.delete(file_path)

  session[:msg] = "#{file_name} has been deleted"
  redirect "/"
end
