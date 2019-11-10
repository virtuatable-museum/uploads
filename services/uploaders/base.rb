module Services
  module Uploaders
    class Base
      include Singleton

      # @!attribute [r] aws_client
      #   @return [Aws::S3::Client] the link to the Amazon S3 API.
      attr_reader :aws_client
      # @!attribute [r] aws_bucket
      #   @return [Aws::S3::Bucket] the representation of the Amazon S3
      #     bucket for the campaigns.
      attr_reader :aws_bucket
      # @!attribute [r] logger
      #   @return [Logger] the logger displaying messages in the console.
      attr_reader :logger
      # @!attribute [r] directory
      #   @return 
      attr_reader :directory

      def initialize
        @aws_client = Aws::S3::Client.new
        @aws_bucket = "virtuatable-#{ENV['RACH_ENV'] || 'development'}"

        create_bucket_if_not_exists
        @logger = Logger.new(STDOUT)
      end

      # Creates the bucket if it does not exist (then the HEAD request fails).
      def create_bucket_if_not_exists
        aws_client.head_bucket(bucket: aws_bucket)
      rescue StandardError
        aws_client.create_bucket(bucket: aws_bucket)
      end

      def list(campaign_id)
        campaign = Arkaan::Campaign.where(id: campaign_id).first
        campaign.invitations.map(&:characters).flatten
      end

      def create(campaign, session, name, content)
        character = Arkaan::Campaigns::Files::Character.new(
          campaign: campaign,
          invitation: invitation(campaign, session),
          mime_type: mime_type(content),
          name: name
        )
        store(campaign, name, content)
        character
      end

      def stored?(campaign, filename)
        parameters = { bucket: aws_bucket, key: fullname(campaign, filename) }
        aws_client.get_object(parameters) != false
      rescue StandardError
        false
      end

      def store(campaign, filename, content)
        aws_client.put_object(
          bucket: aws_bucket,
          key: fullname(campaign, filename),
          body: Base64.decode64(content.split(',', 2).last)
        )
      end

      def self.list(campaign_id)
        instance.list(campaign_id)
      end

      def self.create(campaign, session, name, content)
        instance.create(campaign, session, name, content)
      end

      def self.extract_from_aws(campaign, filename)
        instance.extract_from_aws(campaign, filename)
      end

      private

      def invitation(campaign, session)
        campaign.invitations.where(account: session.account).first
      end

      def mime_type(content)
        content.split(';', 2).first.split(':', 2).last
      end

      def fullname(campaign, filename)
        "#{campaign.id}/#{directory}/#{filename}"
      end
    end
  end
end