# app/controllers/receipt_scans_controller.rb
# トップのレシートを読み取るフォームから届いた画像を受け取り、読み取りに進めてよい画像かを確かめる
class ReceiptScanForm
  include ActiveModel::Model

  # ビューの画像の欄（accept）も、この種類から作る
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 7.megabytes

  attr_accessor :image

  validate :image_must_be_acceptable

  private

    # 上から順に確かめ、最初に当てはまった1つだけをエラーにする（トップの知らせに出すのは1つの文）
    def image_must_be_acceptable
      return errors.add(:image, :no_image) unless image.is_a?(ActionDispatch::Http::UploadedFile)
      return errors.add(:image, :invalid_type) unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
      errors.add(:image, :too_large, size: MAX_IMAGE_SIZE / 1.megabyte) if image.size > MAX_IMAGE_SIZE
    end
end
