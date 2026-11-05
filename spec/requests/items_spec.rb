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
end
