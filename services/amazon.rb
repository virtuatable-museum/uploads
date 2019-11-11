module Services
  class Amazon
    include Singleton

    # @!attribute [r] client
    #   @return [Aws::S3::Client] the link to the Amazon S3 API.
    attr_reader :client
    # @!attribute [r] bucket
    #   @return [Aws::S3::Bucket] the representation of the Amazon S3
    #     bucket for the campaigns.
    attr_reader :bucket
    # @!attribute [r] logger
    #   @return [Logger] the logger displaying messages in the console.
    attr_reader :logger

    def initialize
      @client = Aws::S3::Client.new
      @bucket = "virtuatable-#{ENV['RACK_ENV'] || 'development'}"

      create_bucket_if_not_exists
      @logger = Logger.new(STDOUT)
    end

    # Creates the bucket if it does not exist (then the HEAD request fails).
    def create_bucket_if_not_exists
      client.head_bucket(bucket: bucket)
    rescue StandardError
      client.create_bucket(bucket: bucket)
    end

    def stored?(key)
      client.get_object({ bucket: bucket, key: key }) != false
    rescue StandardError
      false
    end

    def store(key, body)
      client.put_object(bucket: bucket, key: key, body: body)
    end

    def content(key)
      infos(key).body.read.to_s
    end

    # Gets the informations about a file given its filename.
    # @param campaign [Arkaan::Campaign] the campaign the file
    #   is supposed to be in.
    # @param filename [String] the name of the file,
    #   with its extension (eg "file.txt")
    def infos(key)
      client.get_object(bucket: bucket, key: key)
    end

    def size(key)
      infos(key).to_h[:content_length].to_i rescue 0
    end
  end
end