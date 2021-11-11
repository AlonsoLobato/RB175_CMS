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

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Editing content of changes.txt"
  end

  def test_updating_file
    post "/changes.txt", changes: "This is the new content of the file 'changes.txt'"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "This is the new content of the file"
  end

  def test_view_new
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a new document:"
  end

  def test_creating_new
    post "/create", filename: "newdoc.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "newdoc.txt has been created"

    get "/"
    assert_includes last_response.body, "newdoc.txt"
  end

  def test_creating_new_no_name
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Sorry, you must enter a valid name and extension."
  end

  def test_creating_new_no_extension
    post "/create", filename: "newdoc"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Sorry, you must enter a valid name and extension."
  end

  def test_deleting_document
    create_document "newtest.txt"

    post "/newtest.txt/delete"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "newtest.txt has been deleted"

    get "/"
    refute_includes last_response.body, "newtest.txt"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
