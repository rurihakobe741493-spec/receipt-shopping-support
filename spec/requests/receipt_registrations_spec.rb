require "rails_helper"

RSpec.describe "ReceiptRegistrations", type: :request do
  # 今日を 2026-10-30 にする。購入日として受け付ける範囲は 2025-10-31〜2026-10-30
  around do |example|
    travel_to(Date.new(2026, 10, 30)) { example.run }
  end

  # 確認画面から送られる形の値。行は配列なら番号 0, 1, … を付け、ハッシュならその番号のまま使う
  def registration_params(rows, purchased_on: "2026-10-20")
    rows_attributes = rows.is_a?(Hash) ? rows : rows.each_with_index.to_h { |row, index| [ index.to_s, row ] }
    { receipt_registration_form: { purchased_on:, rows_attributes: } }
  end

  # 既存の品目に紐付ける行
  def existing_row(item, receipt_name: "レシートの品名")
    { "selected" => "1", "receipt_name" => receipt_name, "item_id" => item.id.to_s }
  end

  # 新しい品目を作る行（「新規として登録」）
  def new_row(name, cycle_days: "30", receipt_name: "レシートの品名")
    { "selected" => "1", "receipt_name" => receipt_name, "item_id" => "new", "name" => name, "cycle_days" => cycle_days }
  end

  # Turbo Stream で受け取る指定（JavaScript が動いているときのフォームの送信）
  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
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

  describe "POST /receipt_registrations（登録できたとき）" do
    before { sign_in user }

    it "既存の品目だけなら、トップへ戻し、件数入りの知らせを出す" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:)), existing_row(create(:item, user:)) ])

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("receipt_registrations.create.success", count: 2))
      expect(Purchase.count).to eq(2)
    end

    it "Turbo Stream で受け取る指定でも、同じくトップへ 303 で戻す" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:)) ]), headers: turbo_stream_headers

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
    end

    it "新しい品目を作ったら、その数も入った知らせを出す" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:)), new_row("ティッシュ") ])

      expect(flash[:notice]).to eq(I18n.t("receipt_registrations.create.success_with_new_items", new_items_count: 1, count: 2))
    end

    it "送った品目名と周期で、品目を作る" do
      post receipt_registrations_path, params: registration_params([ new_row("ティッシュ", cycle_days: "14") ])

      expect(user.items.pluck(:name, :cycle_days)).to eq([ [ "ティッシュ", 14 ] ])
    end

    it "13桁の番号の足した行は保存し、数字でない番号（NEW_ROW）の行は捨てる" do
      item = create(:item, user:)
      added_item = create(:item, user:)
      template_item = create(:item, user:)
      post receipt_registrations_path, params: registration_params({ "0" => existing_row(item), "1730000000000" => existing_row(added_item), "NEW_ROW" => existing_row(template_item) })

      expect(response).to have_http_status(303)
      expect([ item, added_item, template_item ].map { |row_item| row_item.purchases.count }).to eq([ 1, 1, 0 ])
    end

    it "同じ日の購入記録があるストックの行も、止めずに登録する" do
      item = create(:item, user:)
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 20))
      post receipt_registrations_path, params: registration_params([ existing_row(item) ], purchased_on: "2026-10-20")

      expect(response).to have_http_status(303)
      expect(item.purchases.where(purchased_on: Date.new(2026, 10, 20)).count).to eq(2)
    end
  end

  describe "POST /receipt_registrations（登録できなかったとき）" do
    before { sign_in user }

    it "チェックした行が0なら、422 で確認画面を描き直し、知らせの箱を出して、何も保存しない" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:)).merge("selected" => "0") ])

      expect(response).to have_http_status(422)
      expect(html).to have_css("h1", text: I18n.t("receipt_scans.result.title"))
      expect(html).to have_css("#registration_errors", text: I18n.t("receipt_scans.result.error_notice"))
      expect(html).to have_css("#registration_errors li", text: I18n.t("activemodel.errors.models.receipt_registration_form.attributes.base.no_selected_rows"))
      expect(Purchase.count).to eq(0)
    end

    it "Turbo Stream で受け取る指定なら、422 で main の中を描き直す" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:)).merge("selected" => "0") ]), headers: turbo_stream_headers

      expect(response).to have_http_status(422)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="main">')
    end

    it "購入日が範囲の外なら、欄の下に文を出し、欄と結ぶ" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:)) ], purchased_on: "2026-10-31")

      expect(response).to have_http_status(422)
      expect(html).to have_css("#purchased_on_error", text: "購入日は1年以内の、今日までの日付を入力してください")
      expect(html).to have_css("input[name='receipt_registration_form[purchased_on]'][aria-describedby='purchased_on_error'][aria-invalid='true']")
    end

    it "新規の行の品目名と周期のエラーは、それぞれの欄の下に文を出し、欄と結ぶ" do
      post receipt_registrations_path, params: registration_params([ new_row("", cycle_days: "366") ])

      expect(response).to have_http_status(422)
      expect(html).to have_css("#receipt_registration_form_rows_attributes_0_name_error", text: "品目名を入力してください")
      expect(html).to have_css("input[name='receipt_registration_form[rows_attributes][0][name]'][aria-describedby='receipt_registration_form_rows_attributes_0_name_error']")
      expect(html).to have_css("#receipt_registration_form_rows_attributes_0_cycle_days_error", text: "周期は1〜365の整数で入力してください")
      expect(html).to have_css("input[name='receipt_registration_form[rows_attributes][0][cycle_days]'][aria-describedby='receipt_registration_form_rows_attributes_0_cycle_days_error']")
    end

    it "「選んでください」のままの行は、行の下にストックを選ぶ文を出す" do
      post receipt_registrations_path, params: registration_params([ { "selected" => "1", "receipt_name" => "ティッシュ", "item_id" => "" } ])

      expect(response).to have_http_status(422)
      expect(html).to have_css("ul li", text: "ストックを選んでください")
    end

    it "行の文字列（レシート表記）が空なら、行の下にその文を出す" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item, user:), receipt_name: "") ])

      expect(response).to have_http_status(422)
      expect(html).to have_css("ul li", text: "レシート表記を入力してください")
    end

    it "ほかのユーザーの品目の id を送っても、紐付けずに 422 を返す" do
      other_item = create(:item)
      post receipt_registrations_path, params: registration_params([ existing_row(other_item) ])

      expect(response).to have_http_status(422)
      expect(Purchase.count).to eq(0)
    end

    it "描き直した画面にも、同じ日の警告の値と、行ごとに隠した警告の文を出す" do
      item = create(:item, user:)
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      post receipt_registrations_path, params: registration_params([ existing_row(item), { "selected" => "1", "receipt_name" => "ティッシュ", "item_id" => "" } ])

      expect(response).to have_http_status(422)
      expect(JSON.parse(html.find("form[action='#{receipt_registrations_path}']")["data-warn-same-day-purchased-dates-value"])).to eq({ item.id.to_s => [ "2026-10-01" ] })
      expect(html).to have_css("p[hidden][data-warn-same-day-target='warning']", count: 2, visible: :all)
      expect(template_html).to have_css("p[hidden][data-warn-same-day-target='warning']", count: 1, visible: :all)
    end
  end

  describe "ログインしていないとき" do
    it "登録せずに、ログイン画面へ送る" do
      post receipt_registrations_path, params: registration_params([ existing_row(create(:item)) ])

      expect(response).to redirect_to(new_user_session_path)
      expect(Purchase.count).to eq(0)
    end
  end
end
