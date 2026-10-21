# app/controllers/receipt_scans_controller.rb
class ReceiptScansController < ApplicationController
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 7.megabytes

  before_action :check_image

  def create
    @text = ReceiptOcrService.call(params[:image])
    return redirect_to(root_path, alert: t(".no_text"), status: :see_other) if @text.blank?

    @item_lines = ReceiptTextParser.new(@text).item_lines
    redirect_to root_path, alert: t(".no_item_lines"), status: :see_other if @item_lines.empty?
  rescue ReceiptOcrService::Error => e
    Rails.logger.warn("ReceiptOcrService::Error: #{e.message}")
    redirect_to root_path, alert: t(".ocr_error"), status: :see_other
  end

  private
    def check_image
      message = image_error_message(params[:image])
      redirect_to root_path, alert: message, status: :see_other if message
    end

    def image_error_message(image)
      return t(".no_image") unless image.is_a?(ActionDispatch::Http::UploadedFile)
      return t(".invalid_type") unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
      t(".too_large", size: MAX_IMAGE_SIZE / 1.megabyte) if image.size > MAX_IMAGE_SIZE
    end
end
