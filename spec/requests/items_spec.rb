require "rails_helper"

RSpec.describe "Items", type: :request do
  # 品目を作り、購入日を渡したときは、その日の購入記録を1件足す（周期はファクトリーのまま30日）
  def create_item(user, name, purchased_on = nil)
    item = create(:item, user:, name:)
    create(:purchase, item:, purchased_on:) if purchased_on
    item
  end

  # 一覧の見出し（h2）と行の品目名を、画面の上から順に並べる（見出しの中の改行と空白は1つにまとめる）
  def headings_and_names
    Capybara.string(response.body).all("h2, li a > div:first-child > p:first-child").map { |node| node.text(normalize_ws: true) }
  end

  describe "GET /（ストック一覧）" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    let(:user) { create(:user) }

    before { sign_in user }

    it "品目が0件なら、案内の文を出し、一覧（ul）を出さない" do
      get root_path

      expect(response.body).to include(I18n.t("items.index.empty"))
      expect(response.body).not_to have_css("ul")
    end

    it "ログイン中のユーザーの品目だけを出す" do
      create_item(user, "洗剤")
      create_item(create(:user), "ほかの人の品目")
      get root_path

      expect(headings_and_names).to eq([ "洗剤" ])
    end

    it "購入記録のある行に、最終購入日・残り日数・次回目安を出し、詳細へのリンクにする" do
      item = create_item(user, "洗剤", Date.new(2026, 10, 1))
      get root_path

      expect(response.body).to include(I18n.t("items.row.last_purchased", date: "2026/10/01"))
      expect(response.body).to include(I18n.t("items.days_left.remaining", count: 1))
      expect(response.body).to include(I18n.t("items.row.next_purchase", date: "2026/10/31"))
      expect(response.body).to have_css("li a[href='#{item_path(item)}']")
    end

    it "購入記録のない行には、購入記録なしと出し、残り日数を出さない" do
      create_item(user, "洗剤")
      get root_path

      expect(response.body).to include(I18n.t("items.status.no_purchases"))
      # 右側（残り日数と次回目安）のかたまりがなく、品目名のかたまりだけ
      expect(response.body).to have_css("li a > div", count: 1)
    end

    it "2つの枠とそのほかに分け、それぞれ残り日数の少ない順、同じなら品目名の順、購入記録なしは最後に並べる" do
      # 作る順は、並ぶ順と変えておく
      create_item(user, "まな板")                              # 購入記録なし
      create_item(user, "歯ブラシ", Date.new(2026, 10, 20))    # 残り20日
      create_item(user, "スポンジ", Date.new(2026, 10, 8))     # 残り8日
      create_item(user, "ゴミ袋", Date.new(2026, 10, 8))       # 残り8日（スポンジと同じ）
      create_item(user, "洗剤", Date.new(2026, 10, 7))         # 残り7日
      create_item(user, "シャンプー", Date.new(2026, 10, 1))   # 残り1日
      create_item(user, "ティッシュ", Date.new(2026, 9, 30))   # 残り0日
      create_item(user, "牛乳", Date.new(2026, 9, 29))         # 残り-1日
      create_item(user, "電池", Date.new(2026, 9, 20))         # 残り-10日
      get root_path

      expect(headings_and_names).to eq([
        I18n.t("items.status.overdue"), "電池", "牛乳",
        I18n.t("items.status.running_low"), "ティッシュ", "シャンプー", "洗剤",
        I18n.t("items.index.others_title"), "ゴミ袋", "スポンジ", "歯ブラシ", "まな板"
      ])
    end

    it "枠に入る品目がなければ、見出しを出さずに一覧だけを出す" do
      create_item(user, "歯ブラシ", Date.new(2026, 10, 20))
      create_item(user, "まな板")
      get root_path

      expect(headings_and_names).to eq([ "歯ブラシ", "まな板" ])
    end

    it "もう切れているかもの枠だけなら、そのほかの見出しを出さない" do
      create_item(user, "電池", Date.new(2026, 9, 20))
      get root_path

      expect(headings_and_names).to eq([ I18n.t("items.status.overdue"), "電池" ])
    end

    it "レシートを読み取るフォームを出す" do
      get root_path

      expect(response.body).to have_css("form[action='#{receipt_scans_path}'][method='post'][enctype='multipart/form-data']")
      expect(response.body).to have_css("input[type='file'][name='image'][accept='image/jpeg,image/png,image/webp'][required]")
      expect(response.body).to have_css("input[type='submit'][value='#{I18n.t("items.index.scan.submit")}'][data-turbo-submits-with='#{I18n.t("items.index.scan.submitting")}']")
      expect(response.body).to include(I18n.t("items.index.scan.external_notice"))
      expect(response.body).to include(I18n.t("items.index.scan.reading"))
    end
  end

  describe "GET /items/:id（ストック詳細）" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    let(:user) { create(:user) }

    before { sign_in user }

    it "自分の品目なら、品目名・一覧へ戻るリンク・編集のリンクを出す" do
      item = create_item(user, "洗剤")
      get item_path(item)

      expect(response).to have_http_status(200)
      expect(response.body).to have_css("h1", text: "洗剤")
      expect(response.body).to have_css("a[href='#{root_path}']", text: I18n.t("items.show.back"))
      expect(response.body).to have_css("a[href='#{edit_item_path(item)}']", text: I18n.t("items.show.edit"))
    end

    it "ほかのユーザーの品目なら、404 を返す" do
      item = create_item(create(:user), "ほかの人の品目")
      get item_path(item)

      expect(response).to have_http_status(404)
    end

    it "ない id なら、404 を返す" do
      get item_path(Item.maximum(:id).to_i + 1)

      expect(response).to have_http_status(404)
    end

    it "購入日が2日分あれば、購入履歴から計算した周期で、要約を出す（目安を過ぎたら赤い箱）" do
      item = create_item(user, "洗剤", Date.new(2026, 9, 7))
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      get item_path(item)

      # 周期は 9/7〜10/1 の24日、次回目安は 10/25、残り -5日
      expect(response.body).to have_css("div.border-red-800", text: I18n.t("items.status.overdue"))
      expect(response.body).to include(I18n.t("items.days_left.overdue", count: 5))
      expect(response.body).to include("2026/10/25")
      expect(response.body).to include("2026/10/01")
      expect(response.body).to have_css("dd", text: I18n.t("items.show.cycle_days_value", count: 24) + I18n.t("items.show.cycle_from_purchases"))
    end

    it "購入日が1日分なら、設定値の周期で計算し、残り日数が7日以内なら黄色い箱にする" do
      item = create_item(user, "洗剤", Date.new(2026, 10, 1))
      get item_path(item)

      expect(response.body).to have_css("div.border-yellow-500", text: I18n.t("items.status.running_low"))
      expect(response.body).to include(I18n.t("items.days_left.remaining", count: 1))
      expect(response.body).to have_css("dd", text: I18n.t("items.show.cycle_days_value", count: 30) + I18n.t("items.show.cycle_from_setting"))
    end

    it "残り日数が8日以上なら、状態の言葉を出さず、箱に色を付けない" do
      item = create_item(user, "洗剤", Date.new(2026, 10, 25))
      get item_path(item)

      expect(response.body).not_to include(I18n.t("items.status.overdue"))
      expect(response.body).not_to include(I18n.t("items.status.running_low"))
      expect(response.body).not_to have_css("div.border-red-800, div.border-yellow-500")
    end

    it "購入記録が0件なら、購入記録なしと一言を出し、購入履歴の一覧を出さない" do
      item = create_item(user, "洗剤")
      get item_path(item)

      expect(response.body).to include(I18n.t("items.status.no_purchases"))
      expect(response.body).to have_css("h2", text: I18n.t("items.show.purchases_title"))
      expect(response.body).to include(I18n.t("items.show.purchases_empty"))
      expect(response.body).not_to have_css("ul")
    end

    it "購入履歴を、購入日の新しい順、同じ日はあとから登録したものを上にして、レシート表記と一緒に出す" do
      item = create_item(user, "洗剤")
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1), receipt_name: "レシートA")
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 20), receipt_name: "レシートB")
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 20), receipt_name: "レシートC")
      get item_path(item)

      rows = Capybara.string(response.body).all("ul li").map { |li| li.all("p").map(&:text) }
      expect(rows).to eq([ [ "2026/10/20", "レシートC" ], [ "2026/10/20", "レシートB" ], [ "2026/10/01", "レシートA" ] ])
    end
  end

  describe "GET /items/:id/edit（ストック詳細の編集）" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    let(:user) { create(:user) }

    before { sign_in user }

    it "自分の品目なら、品目名と計算した周期を初期値にした編集の画面を出す" do
      item = create_item(user, "洗剤", Date.new(2026, 9, 7))
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      get edit_item_path(item)

      expect(response).to have_http_status(200)
      expect(response.body).to have_css("h1", text: I18n.t("items.edit.title"))
      expect(response.body).to have_css("form[action='#{item_path(item)}'][novalidate]")
      expect(response.body).to have_field("item_edit_form[name]", with: "洗剤")
      expect(response.body).to have_css("input[name='item_edit_form[cycle_days]'][value='24'][aria-describedby='item_edit_form_cycle_days_note']")
      expect(response.body).to have_css("input[type='hidden'][name='item_edit_form[displayed_cycle_days]'][value='24']", visible: :all)
      expect(response.body).to have_css("input[type='submit'][value='#{I18n.t("items.edit.submit")}'][data-turbo-submits-with='#{I18n.t("items.edit.submitting")}']")
      expect(response.body).to have_css("a[href='#{item_path(item)}']", text: I18n.t("items.edit.cancel"))
    end

    it "ほかのユーザーの品目なら、404 を返す" do
      item = create_item(create(:user), "ほかの人の品目")
      get edit_item_path(item)

      expect(response).to have_http_status(404)
    end
  end

  describe "PATCH /items/:id（ストック詳細の保存）" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    let(:user) { create(:user) }

    before { sign_in user }

    # 既定は「画面に出していた周期30のまま、品目名だけを送る」。変える項目だけを渡す
    def edit_params(**attributes)
      { item_edit_form: { name: "洗剤", cycle_days: "30", displayed_cycle_days: "30" }.merge(attributes) }
    end

    it "品目名だけを変えると、詳細へ戻し、周期を変えたときではない知らせを出す" do
      item = create_item(user, "洗剤")
      patch item_path(item), params: edit_params(name: "台所用洗剤")

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(item_path(item))
      expect(flash[:notice]).to eq(I18n.t("items.update.success"))
      expect(item.reload.name).to eq("台所用洗剤")
      expect(item.cycle_changed_on).to be_nil
    end

    it "周期を変えると、周期と今日の変更日を保存し、補正し直すことも知らせる" do
      item = create_item(user, "洗剤")
      patch item_path(item), params: edit_params(cycle_days: "14")

      expect(response).to have_http_status(303)
      expect(flash[:notice]).to eq(I18n.t("items.update.success_with_cycle_change"))
      expect(item.reload.cycle_days).to eq(14)
      expect(item.cycle_changed_on).to eq(Date.new(2026, 10, 30))
    end

    it "品目名が空なら、422 で描き直し、欄の下の文と欄を aria-describedby で結ぶ" do
      item = create_item(user, "洗剤")
      patch item_path(item), params: edit_params(name: "")

      expect(response).to have_http_status(422)
      expect(response.body).to have_css("#item_edit_form_name_error", text: "品目名を入力してください")
      expect(response.body).to have_css("input[name='item_edit_form[name]'][aria-describedby='item_edit_form_name_error'][aria-invalid='true']")
      expect(item.reload.name).to eq("洗剤")
    end

    it "周期が366なら、422 で描き直し、欄をエラーの文と一言の2つと結ぶ" do
      item = create_item(user, "洗剤")
      patch item_path(item), params: edit_params(cycle_days: "366")

      expect(response).to have_http_status(422)
      expect(response.body).to have_css("#item_edit_form_cycle_days_error", text: "周期は1〜365の整数で入力してください")
      expect(response.body).to have_css("input[name='item_edit_form[cycle_days]'][aria-describedby='item_edit_form_cycle_days_error item_edit_form_cycle_days_note'][aria-invalid='true']")
      expect(item.reload.cycle_days).to eq(30)
    end

    it "送られた変更日と品目の id は受け取らない" do
      item = create_item(user, "洗剤")
      other_item = create_item(user, "スポンジ")
      patch item_path(item), params: edit_params(name: "台所用洗剤", cycle_changed_on: "2026-01-01", item_id: other_item.id)

      expect(item.reload.cycle_changed_on).to be_nil
      expect(other_item.reload.name).to eq("スポンジ")
    end

    it "ほかのユーザーの品目なら、404 を返し、保存しない" do
      item = create_item(create(:user), "ほかの人の品目")
      patch item_path(item), params: edit_params(name: "書き換えた名前")

      expect(response).to have_http_status(404)
      expect(item.reload.name).to eq("ほかの人の品目")
    end
  end

  describe "ログインしていないとき" do
    it "詳細・編集・保存は、ログイン画面へ送る" do
      item = create(:item)

      get item_path(item)
      expect(response).to redirect_to(new_user_session_path)

      get edit_item_path(item)
      expect(response).to redirect_to(new_user_session_path)

      patch item_path(item), params: { item_edit_form: { name: "書き換えた名前" } }
      expect(response).to redirect_to(new_user_session_path)
      expect(item.reload.name).not_to eq("書き換えた名前")
    end
  end
end
