module Services
  module Uploaders
    class Base

      # @!attribute [r] amazon
      #   @return [Services::Amazon] the AWS S3 wrapper to store files in.
      attr_reader :amazon

      attr_reader :campaign

      attr_reader :session

      attr_reader :directory

      # @abstract Subclasses are expected to implement such a constructor
      # @!method initialize
      #   Builds a new file uploader for this category of files.
      #   @param campaign [Arkaan::Campaign] the campaign to insert the file into.
      #   @param session [Arkaan::Authentication::Session] the session inserting the file.

      def initialize(campaign:, session:)
        @amazon = Services::Amazon.instance
        @campaign = campaign
        @session = session
      end

      # @abstract Subclasses are expected to implement #up
      # @!method up
      #   Inserts the document in the database and stores it on AWS S3
      #   @param name [String] the name of the file to insert in the campaign.
      #   @oaram content [String] the text content to insert in the campaign.
      
      # @abstract Subclasses are expected to implement #down
      # @!method down
      #   Removes the document from the database and from AWS S3
      #   @param name [String] the name of the file to remove from the campaign.

      def create(campaign, session, name, content)
        file = create_file(campaign, session, name, content)
        store(campaign, name, content)
        post_actions(file) if respond_to?(:post_actions)
        file
      end

      def stored?(campaign, filename)
        parameters = { bucket: aws_bucket, key: fullname(campaign, filename) }
        aws_client.get_object(parameters) != false
      rescue StandardError
        false
      end

      def store(campaign, filename, content)
        key = fullname(campaign, filename)
        body = Base64.decode64(content.split(',', 2).last)
        amazon.store(key, body)
      end

      def content(campaign, filename)
        file_infos(campaign, filename).body.read.to_s
      end

      private

      def mime_type(content)
        content.split(';', 2).first.split(':', 2).last
      end

      def fullname(campaign, filename)
        "#{campaign.id}/#{directory}/#{filename}"
      end
    end
  end
end