# app/controllers/receipt_scans_controller.rb
class ReceiptScansController < ApplicationController
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 7.megabytes
  READ_FAILED_MESSAGE = "読み取れませんでした。もう一度撮影してください。"

  before_action :check_image

  def create
    @text = ReceiptOcrService.call(params[:image])
    redirect_to root_path, alert: READ_FAILED_MESSAGE, status: :see_other if @text.blank?
  rescue ReceiptOcrService::Error => e
    Rails.logger.warn("ReceiptOcrService::Error: #{e.message}")
    redirect_to root_path, alert: READ_FAILED_MESSAGE, status: :see_other
  end

  private
    def check_image
      message = image_error_message(params[:image])
      redirect_to root_path, alert: message, status: :see_other if message
    end

    def image_error_message(image)
      return "画像を選んでください。" unless image.is_a?(ActionDispatch::Http::UploadedFile)
      return "JPEG・PNG・WEBP の画像を選んでください。" unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
      "画像が大きすぎます（#{MAX_IMAGE_SIZE / 1.megabyte}MBまで）。" if image.size > MAX_IMAGE_SIZE
    end
end
