require "rails_helper"

RSpec.describe "ReceiptScans", type: :request do
  around do |example|
    travel_to(Date.new(2026, 10, 30)) { example.run }
  end

  # 読み取った全文の例（購入日と、品目行が3つ。1つ目と3つ目は同じ文字列）
  def receipt_text
    <<~TEXT
      テストストア
      2026年10月20日
      ティッシュ ¥298
      洗剤 ¥398
      ティッシュ ¥298
      小計 ¥994
    TEXT
  end

  # Turbo Stream で受け取る指定（JavaScript が動いているときのフォームの送信）
  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def receipt_image
    fixture_file_upload("receipt.jpg", "image/jpeg")
  end

  # 中身の大きさだけを決めた画像（大きさの確かめ用）
  def image_of_size(bytes)
    Rack::Test::UploadedFile.new(StringIO.new("a" * bytes), "image/jpeg", original_filename: "large.jpg")
  end

  # 応答の HTML から、部品を取り出せるようにする
  def html
    Capybara.string(response.body)
  end

  # <template> の中身（足す行のひな形）。Capybara は <template> の中身を文書から外すので、応答の文字列から取り出して調べる
  def template_html
    Capybara.string(response.body[%r{<template[^>]*>(.*?)</template>}m, 1])
  end

  let(:user) { create(:user) }

  describe "POST /receipt_scans（画像の確かめで止まる道）" do
    before { sign_in user }

    it "画像がなければ、読み取らずにトップへ戻し、知らせを出す" do
      expect(ReceiptOcrService).not_to receive(:call)
      post receipt_scans_path

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("activemodel.errors.models.receipt_scan_form.attributes.image.no_image"))
    end

    it "JPEG・PNG・WEBP でなければ、読み取らずにトップへ戻し、知らせを出す" do
      expect(ReceiptOcrService).not_to receive(:call)
      post receipt_scans_path, params: { image: fixture_file_upload("receipt.txt", "text/plain") }

      expect(response).to have_http_status(303)
      expect(flash[:alert]).to eq(I18n.t("activemodel.errors.models.receipt_scan_form.attributes.image.invalid_type"))
    end

    it "7MB を1バイトでも超えると、読み取らずにトップへ戻し、知らせを出す" do
      expect(ReceiptOcrService).not_to receive(:call)
      post receipt_scans_path, params: { image: image_of_size(7.megabytes + 1) }

      expect(response).to have_http_status(303)
      expect(flash[:alert]).to eq(I18n.t("activemodel.errors.models.receipt_scan_form.attributes.image.too_large", size: 7))
    end

    it "ちょうど 7MB なら、読み取りへ進む" do
      allow(ReceiptOcrService).to receive(:call).and_return(receipt_text)
      post receipt_scans_path, params: { image: image_of_size(7.megabytes) }

      expect(response).to have_http_status(200)
      expect(ReceiptOcrService).to have_received(:call)
    end
  end

  describe "POST /receipt_scans（読み取れなかった道）" do
    before { sign_in user }

    it "文字が取れなければ、トップへ戻し、撮り直しの知らせを出す" do
      allow(ReceiptOcrService).to receive(:call).and_return("")
      post receipt_scans_path, params: { image: receipt_image }

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("receipt_scans.create.no_text"))
    end

    it "品目行が見つからなければ、トップへ戻し、撮り直しの知らせを出す" do
      allow(ReceiptOcrService).to receive(:call).and_return("2026年10月20日\n小計 ¥0\n")
      post receipt_scans_path, params: { image: receipt_image }

      expect(response).to have_http_status(303)
      expect(flash[:alert]).to eq(I18n.t("receipt_scans.create.no_item_lines"))
    end

    it "Vision API のエラーなら、トップへ戻し、時間をおく知らせを出す" do
      allow(ReceiptOcrService).to receive(:call).and_raise(ReceiptOcrService::Error, "Bad image data.")
      post receipt_scans_path, params: { image: receipt_image }

      expect(response).to have_http_status(303)
      expect(flash[:alert]).to eq(I18n.t("receipt_scans.create.ocr_error"))
    end
  end

  describe "POST /receipt_scans（確認画面）" do
    before do
      sign_in user
      allow(ReceiptOcrService).to receive(:call).and_return(receipt_text)
    end

    it "Turbo Stream で受け取る指定なら、main の中を確認画面に置き換える" do
      post receipt_scans_path, params: { image: receipt_image }, headers: turbo_stream_headers

      expect(response).to have_http_status(200)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="main">')
      expect(response.body).to include(I18n.t("receipt_scans.result.title"))
    end

    it "指定がなければ（JavaScript が動かないとき）、確認画面のページを返す" do
      post receipt_scans_path, params: { image: receipt_image }

      expect(response).to have_http_status(200)
      expect(response.media_type).to eq("text/html")
      expect(html).to have_css("header")
      expect(html).to have_css("h1", text: I18n.t("receipt_scans.result.title"))
    end

    it "フォームの送り先・novalidate・JavaScript の部品・ボタン・キャンセルを出す" do
      post receipt_scans_path, params: { image: receipt_image }

      expect(html).to have_css("form[action='#{receipt_registrations_path}'][method='post'][novalidate][data-controller='prevent-enter-submit warn-same-day']")
      expect(html).to have_css("input[type='submit'][value='#{I18n.t("receipt_scans.result.submit")}'][data-turbo-submits-with='#{I18n.t("receipt_scans.result.submitting")}']")
      expect(html).to have_css("a[href='#{root_path}']", text: I18n.t("receipt_scans.result.cancel"))
    end

    it "購入日の欄に、読み取った日と、選べる範囲（1年前の翌日〜今日）を入れる" do
      post receipt_scans_path, params: { image: receipt_image }

      expect(html).to have_css("input[type='date'][name='receipt_registration_form[purchased_on]'][value='2026-10-20'][min='2025-10-31'][max='2026-10-30']")
      expect(html).not_to have_css("#purchased_on_missing")
    end

    it "品目行を、同じ文字列の行も含めて、レシートの順にすべてチェックした状態で並べる" do
      post receipt_scans_path, params: { image: receipt_image }

      expect(html.all("ul input[name$='[receipt_name]']").map(&:value)).to eq([ "ティッシュ", "洗剤", "ティッシュ" ])
      checkboxes = html.all("ul input[type='checkbox'][name$='[selected]']")
      expect(checkboxes.size).to eq(3)
      expect(checkboxes.map { |checkbox| checkbox[:checked] }).to all(be_present)
      expect(html).to have_css("input[name='receipt_registration_form[rows_attributes][0][receipt_name]']")
      expect(html).to have_css("select[name='receipt_registration_form[rows_attributes][0][item_id]']")
    end

    it "ストックの選択肢を、選んでください・新規として登録・ログイン中のユーザーの品目（名前順）の順に並べる" do
      create(:item, user:, name: "洗剤")
      create(:item, user:, name: "スポンジ")
      create(:item, name: "ほかの人の品目")
      post receipt_scans_path, params: { image: receipt_image }

      options = html.first("ul select").all("option").map(&:text)
      expect(options).to eq([ I18n.t("receipt_scans.row.select_prompt"), I18n.t("receipt_scans.result.new_item"), "スポンジ", "洗剤" ])
    end

    it "足す行のひな形（番号の目印 NEW_ROW、チェックあり）と、初めは隠した行を足すボタンを出す" do
      post receipt_scans_path, params: { image: receipt_image }

      expect(template_html).to have_css("input[type='checkbox'][name='receipt_registration_form[rows_attributes][NEW_ROW][selected]'][checked]")
      expect(template_html).to have_css("input[name='receipt_registration_form[rows_attributes][NEW_ROW][receipt_name]']")
      expect(html).to have_css("button[type='button'][hidden][data-action='add-row#add']", text: I18n.t("receipt_scans.result.add_row"), visible: :all)
    end

    it "同じ日の警告に使う購入日は、ログイン中のユーザーの品目の分だけを渡し、警告の文は行ごとに隠して置く" do
      item = create(:item, user:)
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      create(:purchase, purchased_on: Date.new(2026, 10, 2))
      post receipt_scans_path, params: { image: receipt_image }

      expect(JSON.parse(html.find("form[action='#{receipt_registrations_path}']")["data-warn-same-day-purchased-dates-value"])).to eq({ item.id.to_s => [ "2026-10-01" ] })
      expect(html).to have_css("input[name='receipt_registration_form[purchased_on]'][data-warn-same-day-target='purchasedOn'][data-action='change->warn-same-day#update']")
      # 読み取った3行と、足す行のひな形の1行
      expect(html).to have_css("select[data-action='change->warn-same-day#update']", count: 3)
      expect(template_html).to have_css("select[data-action='change->warn-same-day#update']", count: 1)
      expect(html).to have_css("p[hidden][data-warn-same-day-target='warning']", text: I18n.t("receipt_scans.row.same_day_warning"), count: 3, visible: :all)
      expect(template_html).to have_css("p[hidden][data-warn-same-day-target='warning']", text: I18n.t("receipt_scans.row.same_day_warning"), count: 1, visible: :all)
    end

    it "購入日が読み取れなければ、帯を出し、欄を空にして帯と結ぶ" do
      allow(ReceiptOcrService).to receive(:call).and_return("ティッシュ ¥298\n小計 ¥298\n")
      post receipt_scans_path, params: { image: receipt_image }

      expect(html).to have_css("#purchased_on_missing", text: I18n.t("receipt_scans.result.purchased_on_missing"))
      expect(html).to have_css("input[name='receipt_registration_form[purchased_on]'][aria-describedby='purchased_on_missing']:not([value])")
    end
  end

  describe "ログインしていないとき" do
    it "読み取らずに、ログイン画面へ送る" do
      expect(ReceiptOcrService).not_to receive(:call)
      post receipt_scans_path, params: { image: fixture_file_upload("receipt.jpg", "image/jpeg") }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
