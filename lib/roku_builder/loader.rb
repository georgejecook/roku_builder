module RokuBuilder
  class Loader < Util

    def sideload(root_dir:)
      $root_dir = root_dir

      folders = ['resources', 'source']
      files = ['manifest']
      file = Tempfile.new('pkg')
      outfile = "#{file.path}.zip"
      file.unlink

      io = Zip::File.open(outfile, Zip::File::CREATE)

      folders.each do |folder|
        base_folder = File.join($root_dir, folder)
        entries = Dir.entries(base_folder)
        entries.delete(".")
        entries.delete("..")
        writeEntries($root_dir, entries, folder, io)
      end

      writeEntries($root_dir, files, "", io)

      io.close()

      path = "/plugin_install"

      conn = Faraday.new(url: $url) do |f|
        f.request :digest, $dev_username, $dev_password
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
      payload =  {
        mysubmit: "Replace",
        archive: Faraday::UploadIO.new(outfile, 'application/zip')
      }
      response = conn.post path, payload

      File.delete(outfile)

      if response.status == 200 and response.body =~ /Install Success/
        return true
      end

      return false
    end

    private

    def writeEntries(root_dir, entries, path, io)
      entries.each { |e|
        zipFilePath = path == "" ? e : File.join(path, e)
        diskFilePath = File.join(root_dir, zipFilePath)
        if File.directory?(diskFilePath)
          io.mkdir(zipFilePath)
          subdir =Dir.entries(diskFilePath); subdir.delete("."); subdir.delete("..")
          writeEntries(root_dir, subdir, zipFilePath, io)
        else
          io.get_output_stream(zipFilePath) { |f| f.puts(File.open(diskFilePath, "rb").read()) }
        end
      }
    end
  end
end