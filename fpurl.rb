require 'net/http'
require 'fileutils'

# Abstraction for working with Filepicker.IO URLs
class FPUrl
  @uri = nil
  @apikey = nil

  def initialize(apikey, url)
    @apikey = apikey
    @uri = URI(url)
    @uri.query = "key=#{@apikey}"
  end

  def uri
    @uri
  end

  # Download the contents of the URL to disk
  # @param {String} path where to store it on disk
  def download(output_path, options={})
    # Use the original filename, but use the passed output_path as the directory to hold it
    if options[:use_original_filename]
      output_dir = if File.directory?(output_path) || output_path.end_with?('/')
        output_path # It is a directory
      else
        File.dirname(output_path) # Extract the directory from the file path
      end
      fname = filename()
      output_path = File.join(output_dir, fname) if fname != nil
    end

    output_dir = File.dirname(output_path)
    FileUtils.mkdir_p(output_dir) if !Dir.exists?(output_dir)
    
    # Call wget to download the file
    exit_code = 0
    # Continue downloads, create directories, 10s timeout, retry 3 times, output to output_path
    cmd = "wget -c -x -T10 -t3 #{@uri} -O #{output_path}"
    #Rails.logger.info "Downloading FPUrl:: #{cmd}"
    `#{cmd} 2>&1`
    exit_code = $?.to_i

    if exit_code == 0
      #Rails.logger.info "... success"
      revoke if options[:revoke]
    else
      #Rails.logger.error "Could not download #{@uri.request_uri}, got an exit code of #{exit_code}"
    end

    return File.new(output_path)
  end

  # Revoke access to the URL so nobody else can use it
  # @return {Boolean} deleted successfully
  def revoke
    request = Net::HTTP::Delete.new(@uri.request_uri)
    response = http.request(request)

    case response
    when Net::HTTPForbidden
      #Rails.logger.error "Could not revoke access to #{@uri.request_uri}, got FORBIDDEN"
    end
  end  

  # Get the filename of the file on an uploaded URL
  # @return {String} filename for the file uploaded to that URL
  def filename
    request = Net::HTTP::Get.new(@uri.request_uri)
    response = http.request(request)
    filename = nil

    case response
    when Net::HTTPForbidden
      #Rails.logger.error "Could not get filename for #{@uri.request_uri}, got FORBIDDEN"
    else
      disposition = response['content-disposition']
      filename = disposition.match(/^attachment; filename="(.+)"$/)[1] if disposition
      
      if filename
        # Split the name when finding a period which is preceded by some
        # character, and is followed by some character other than a period,
        # if there is no following period that is followed by something
        # other than a period (yeah, confusing, I know)
        fn = filename.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m

        # We now have one or two parts (depending on whether we could find
        # a suitable period). For each of these parts, replace any unwanted
        # sequence of characters with an underscore
        fn.map! { |s| s.gsub /[^a-z0-9\-]+/i, '_' }

        # Finally, join the parts with a period and return the result
        filename = fn.join '.'
      else
        # The filename is nil - grab it from the URL instead
        File.basename(@uri.to_s)
      end
    end
    
    return filename
  end

  # Take a CSV list of FP URLs and return FPUrl instances in an array for each one
  # @param {String} apikey
  # @param {String} urls_csv
  def self.build(apikey, urls_csv)
    return [] if urls_csv == nil || urls_csv.strip.empty?
    fpurls = []
    urls_csv.split(',').each do |url|
      fpurls << self.new(apikey, url)
    end
    fpurls
  end

protected

  # @return Net::HTTP object configured for the URL and SSL
  def http
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end
end