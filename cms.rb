require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

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

# ----- ROUTES

# View list of documents in CMS
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }

  erb :index
end

# View create new file / document
get "/new" do
  erb :new
end

# Create new file / document
post "/create" do
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
  @file_name = params[:filename]
  file_path = File.join(data_path, @file_name)
  @content = File.read(file_path)

  erb :edit
end

# Edit page
post "/:filename" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  changes = params[:changes]

  File.write(file_path, changes)

  session[:msg] = "#{file_name} has been updated"
  redirect "/"
end

# View delete file form
post "/:filename/delete" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  File.delete(file_path)

  session[:msg] = "#{file_name} has been deleted"
  redirect "/"
end
