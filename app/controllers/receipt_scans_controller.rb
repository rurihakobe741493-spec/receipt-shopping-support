# app/controllers/receipt_scans_controller.rb
class ReceiptScansController < ApplicationController
  # ゲストの読み取りの回数（Vision API の無料枠を守るため）
  GUEST_SCANS_PER_GUEST = 3
  GUEST_SCANS_PER_DAY = 20

  # 画像の確かめより前で数える（選び間違えた画像も1回に数える。手元では Vision API を呼ばずに上限を確かめられる）
  # 1人あたりを先に数える（上限に達したゲストの送信で、ゲスト全体の回数を減らさないように）
  rate_limit to: GUEST_SCANS_PER_GUEST, within: User::GUEST_LIFETIME, by: -> { current_user.id }, name: "guest",
             with: -> { redirect_to root_path, alert: t(".guest_limit", count: GUEST_SCANS_PER_GUEST), status: :see_other },
             only: :create, if: -> { current_user.guest? }
  rate_limit to: GUEST_SCANS_PER_DAY, within: 1.day, by: -> { "all" }, name: "all_guests",
             with: -> { redirect_to root_path, alert: t(".guests_daily_limit"), status: :see_other },
             only: :create, if: -> { current_user.guest? }
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
