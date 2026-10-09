require "google/cloud/vision"

# レシートの画像を Cloud Vision API で読み取り、全文の文字列を返す
class ReceiptOcrService
  class Error < StandardError; end

  def self.call(image, feature: :TEXT_DETECTION)
    new(image, feature:).call
  end

  def initialize(image, feature:)
    @image = image
    @feature = feature
  end

  def call
    response = client.batch_annotate_images(
      requests: [ { image: { content: @image.read }, features: [ { type: @feature } ] } ]
    ).responses.first
    raise Error, response.error.message if response.error

    response.full_text_annotation&.text.to_s
  rescue Google::Cloud::Error => e
    raise Error, e.message
  end

  private
    def client
      Google::Cloud::Vision.image_annotator do |config|
        config.credentials = credentials
      end
    end

    def credentials
      json = Rails.application.credentials.dig(:google_cloud, :vision_credentials)
      raise Error, "Cloud Vision の認証情報がありません" if json.blank?

      JSON.parse(json)
    end
end
