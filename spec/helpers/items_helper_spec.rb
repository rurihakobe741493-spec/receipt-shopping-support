require "rails_helper"

RSpec.describe ItemsHelper, type: :helper do
  describe "#days_left_text" do
    it "1なら、残りの日数の文を返す" do
      expect(helper.days_left_text(1)).to eq(I18n.t("items.days_left.remaining", count: 1))
    end

    it "0なら、今日が目安の文を返す" do
      expect(helper.days_left_text(0)).to eq(I18n.t("items.days_left.today"))
    end

    it "-1なら、過ぎた日数を正の数にした文を返す" do
      expect(helper.days_left_text(-1)).to eq(I18n.t("items.days_left.overdue", count: 1))
    end
  end
end
