ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_view_index
    create_document "about.md"
    create_document "history.txt"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "history.txt"
    assert_includes last_response.body, "changes.txt"
  end

  def test_view_history
    create_document "history.txt", "1995 - Ruby 0.95 released."

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1995 - Ruby 0.95 released."
  end

  def test_view_about
    create_document "about.md", "<h1>CMS project</h1>"

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>CMS project</h1>"
  end

  def test_view_changes
    create_document "changes.txt", "This is the new content of the file 'changes.txt'"

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal last_response.body, "This is the new content of the file 'changes.txt'"
  end

  # Long way of testing messages in session (see short way below)
  def test_not_found
    get "/nonexisting.txt" # Attempt to access a nonexistent file

    assert_equal 302, last_response.status # Assert that the user was redirected

    get last_response["Location"] # Request the page that the user was redirected to

    assert_equal 200, last_response.status
    assert_includes last_response.body, "nonexisting.txt does not exist" # Assert that redirected page includes the error msg

    get "/" # Reload the page
    refute_includes last_response.body, "nonexisting.txt does not exist" # Assert that the error msg has been removed
  end

  def test_view_edit
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Editing content of changes.txt"
  end

  def test_view_edit_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "Sorry, you must be signed in to perform this action.", session[:msg]
  end

  # Short way of accessing session messages (use session method defined above)
  def test_updating_file
    post "/changes.txt", {content: "This is the new content of the file 'changes.txt'"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated", session[:msg]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
  end

  def test_updating_file_signed_out
    post "/changes.txt", {content: "This is the new content of the file 'changes.txt'"}

    assert_equal 302, last_response.status
    assert_equal "Sorry, you must be signed in to perform this action.", session[:msg]
  end

  def test_view_new
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "Sorry, you must be signed in to perform this action.", session[:msg]
  end

  def test_creating_new
    post "/create", {filename: "newdoc.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "newdoc.txt has been created.", session[:msg]

    get "/"
    assert_includes last_response.body, "newdoc.txt"
  end

  def test_creating_new_signed_out
    post "/create", {filename: "newdoc.txt"}

    assert_equal 302, last_response.status
    assert_equal "Sorry, you must be signed in to perform this action.", session[:msg]
  end

  def test_creating_new_no_name
    post "/create", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Sorry, you must enter a valid name and extension."
  end

  def test_creating_new_no_extension
    post "/create", {filename: "newdoc"}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Sorry, you must enter a valid name and extension."
  end

  def test_deleting_document
    create_document "newtest.txt"

    post "/newtest.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "newtest.txt has been deleted", session[:msg]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_deleting_document_signed_out
    create_document "newtest.txt"

    post "/newtest.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "Sorry, you must be signed in to perform this action.", session[:msg]
  end

  def test_duplicate_documents
    create_document "newtest.txt"

    post "/newtest.txt/duplicate", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "newtest_copy.txt has been created.", session[:msg]

    get "/"
    assert_includes last_response.body, "newtest_copy.txt"
  end

  def test_duplicating_signed_out
    create_document "newtest.txt"

    post "/newtest.txt/duplicate"
    assert_equal 302, last_response.status
    assert_equal "Sorry, you must be signed in to perform this action.", session[:msg]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:msg]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, { "rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out.", session[:msg]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
