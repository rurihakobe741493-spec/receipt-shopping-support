require "rails_helper"

RSpec.describe "Purchases", type: :request do
  around do |example|
    travel_to(Date.new(2026, 10, 30)) { example.run }
  end

  describe "DELETE /items/:item_id/purchases/:id" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "自分の品目の購入記録なら、1件消して詳細へ戻し、日付入りの知らせを出す。品目は残す" do
      item = create(:item, user:)
      purchase = create(:purchase, item:, purchased_on: Date.new(2026, 10, 20))
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))

      expect { delete item_purchase_path(item, purchase) }.to change(Purchase, :count).by(-1)
      expect(response).to have_http_status(303)
      expect(response).to redirect_to(item_path(item))
      expect(flash[:notice]).to eq(I18n.t("purchases.destroy.success", date: "2026/10/20"))
      expect(Item.exists?(item.id)).to be(true)
    end

    it "最後の1件を消すと、詳細に購入履歴の見出しと、0件のときの一言を出す" do
      item = create(:item, user:)
      purchase = create(:purchase, item:)
      delete item_purchase_path(item, purchase)
      follow_redirect!

      expect(response.body).to have_css("h2", text: I18n.t("items.show.purchases_title"))
      expect(response.body).to include(I18n.t("items.show.purchases_empty"))
    end

    it "ほかのユーザーの品目と購入記録なら、404 を返し、消さない" do
      purchase = create(:purchase)

      expect { delete item_purchase_path(purchase.item, purchase) }.not_to change(Purchase, :count)
      expect(response).to have_http_status(404)
    end

    it "自分の品目の id と、ほかのユーザーの購入記録の id なら、404 を返し、消さない" do
      item = create(:item, user:)
      other_purchase = create(:purchase)

      expect { delete item_purchase_path(item, other_purchase) }.not_to change(Purchase, :count)
      expect(response).to have_http_status(404)
    end

    it "自分の品目の id と、自分のほかの品目の購入記録の id なら、404 を返し、消さない" do
      item = create(:item, user:)
      other_item_purchase = create(:purchase, item: create(:item, user:))

      expect { delete item_purchase_path(item, other_item_purchase) }.not_to change(Purchase, :count)
      expect(response).to have_http_status(404)
    end

    it "ない品目の id なら、404 を返す" do
      delete item_purchase_path(Item.maximum(:id).to_i + 1, Purchase.maximum(:id).to_i + 1)

      expect(response).to have_http_status(404)
    end

    it "自分の品目の id と、ない購入記録の id なら、404 を返す" do
      item = create(:item, user:)
      delete item_purchase_path(item, Purchase.maximum(:id).to_i + 1)

      expect(response).to have_http_status(404)
    end
  end

  describe "ストック詳細の各行の削除のボタン" do
    it "送り先・確認の文・読み上げの名前に、日付とレシート表記を入れる" do
      item = create(:item)
      purchase = create(:purchase, item:, purchased_on: Date.new(2026, 10, 20), receipt_name: "台所用洗剤")
      sign_in item.user
      get item_path(item)

      form = "form[action='#{item_purchase_path(item, purchase)}']"
      expect(response.body).to have_css("#{form}[data-turbo-confirm='#{I18n.t("purchases.purchase.confirm", date: "2026/10/20", receipt_name: "台所用洗剤")}']")
      expect(response.body).to have_css("#{form} input[name='_method'][value='delete']", visible: :all)
      expect(response.body).to have_css("#{form} button[aria-label='#{I18n.t("purchases.purchase.destroy_label", date: "2026/10/20", receipt_name: "台所用洗剤")}']")
    end
  end

  describe "ログインしていないとき" do
    it "削除は、ログイン画面へ送り、消さない" do
      purchase = create(:purchase)

      expect { delete item_purchase_path(purchase.item, purchase) }.not_to change(Purchase, :count)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
