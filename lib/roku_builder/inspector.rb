module RokuBuilder

  # Collects information on a package for submission
  class Inspector < Util

    # Inspects the given pkg
    # @param pkg [String] Path to the pkg to be inspected
    # @param password [String] Password for the given pkg
    # @return [Hash] Package information. Contains the following keys:
    #   * app_name
    #   * dev_id
    #   * creation_date
    #   * dev_zip
    def inspect(pkg:, password:)

      # upload new key with password
      path = "/plugin_inspect"
      conn = Faraday.new(url: @url) do |f|
        f.request :digest, @dev_username, @dev_password
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
      payload =  {
        mysubmit: "Inspect",
        passwd: password,
        archive: Faraday::UploadIO.new(pkg, 'application/octet-stream')
      }
      response = conn.post path, payload

      app_name = /App Name:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)
      dev_id = nil
      creation_date = nil
      dev_zip = nil
      if app_name
        app_name = app_name[1]
        dev_id = /Dev ID:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)[1]
        creation_date = /Creation Date:\s*<\/td>\s*<td>\s*<font[^>]*>\s*<script[^>]*>\s*var d = new Date\(([^\)]*)\)[^<]*<\/script><\/font>\s*<\/td>/.match(response.body.gsub("\n", ''))[1]
        dev_zip = /dev.zip:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)[1]
      else
        app_name = /App Name:[^<]*<div[^>]*>([^<]*)<\/div>/.match(response.body)[1]
        dev_id = /Dev ID:[^<]*<div[^>]*><font[^>]*>([^<]*)<\/font><\/div>/.match(response.body)[1]
        creation_date = /new Date\(([^\/]*)\)/.match(response.body.gsub("\n", ''))[1]
        dev_zip = /dev.zip:[^<]*<div[^>]*><font[^>]*>([^<]*)<\/font><\/div>/.match(response.body)[1]
      end

      return {app_name: app_name, dev_id: dev_id, creation_date: Time.at(creation_date.to_i).to_s, dev_zip: dev_zip}

    end
  end
end