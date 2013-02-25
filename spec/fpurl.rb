require 'spec_helper'
require File.join(File.dirname(__FILE__), '..', "fpurl.rb")

describe :FPUrl do
  API_KEY = 'YOUR_API_KEY'
  FP_URL = 'https://www.filepicker.io/api/file/YOUR_FP_FILE_HANDLE'

  EXPECTED_FILENAME = 'Test.pdf'

  before :all do
    # TODO: Upload a file for tests: also 1 which can be revoked
    @fp = FPUrl.new(API_KEY, FP_URL)
  end

  it "should initialize" do
    @fp.should_not be_nil
  end

  it "should get the filename" do
    @fp.filename().should eq(EXPECTED_FILENAME)
  end

  it "should download to a given filename" do
    path = "/tmp/test_download_#{Time.now.to_i}.pdf"
    @fp.download(path)

    File.exists?(path).should be_true
    File.delete(path) # cleanup
  end

  it "should download to the original filename to a given path" do
    path = "/tmp/notyetmade/"
    file = @fp.download(path, { :use_original_filename => true })

    File.exists?(path).should be_true
    File.delete(file.path) # cleanup
  end

  it "should download and revoke permissions" do
    path = "/tmp/"
    file = @fp.download(path, { :use_original_filename => true, :revoke => true })

    File.exists?(path).should be_true
    File.delete(file.path) # cleanup

    attempt_path = "/tmp/#{Time.now.to_i}"
    attempt_file = @fp.download(attempt_path)
    File.exists?(attempt_file).should be_false
  end

  it "should build fpurls from a csv" do
    fpurls = FPUrl.build(API_KEY, "#{FP_URL},#{FP_URL},#{FP_URL}")
    fpurls.length.should eq(3)
  end

end