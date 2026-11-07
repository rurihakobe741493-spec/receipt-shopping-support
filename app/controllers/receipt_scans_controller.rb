# app/controllers/receipt_scans_controller.rb
class ReceiptScansController < ApplicationController
  before_action :check_image

  def create
    text = ReceiptOcrService.call(params[:image])
    return redirect_to(root_path, alert: t(".no_text"), status: :see_other) if text.blank?

    parser = ReceiptTextParser.new(text)
    item_lines = parser.item_lines
    return redirect_to(root_path, alert: t(".no_item_lines"), status: :see_other) if item_lines.empty?

    @form = ReceiptRegistrationForm.from_receipt(user: current_user, purchased_on: parser.purchased_on, item_lines:)
  rescue ReceiptOcrService::Error => e
    Rails.logger.warn("ReceiptOcrService::Error: #{e.message}")
    redirect_to root_path, alert: t(".ocr_error"), status: :see_other
  end

  private
    # 読み取りに進めてよい画像でなければ、読み取らずにトップへ戻す（確かめの決まりは ReceiptScanForm）
    def check_image
      scan_form = ReceiptScanForm.new(image: params[:image])
      redirect_to root_path, alert: scan_form.errors.first.message, status: :see_other if scan_form.invalid?
    end
end
