require "rails_helper"

RSpec.describe ItemsHelper, type: :helper do
  describe "#days_left_tag" do
    # 文の全体と、大きくする span の中身を返す
    def text_and_number(html)
      node = Capybara.string(html)
      [ node.text, node.find("span").text ]
    end

    it "1なら、残りの日数の文を返し、数字を span で包む" do
      expect(text_and_number(helper.days_left_tag(1, form: :short))).to eq([ "あと1日", "1" ])
    end

    it "0なら、今日が目安の文を返し、「今日」を span で包む" do
      expect(text_and_number(helper.days_left_tag(0, form: :short))).to eq([ "今日が目安", "今日" ])
    end

    it "-1でトップのカード（short）なら、過ぎた日数を正の数にした短い文を返す" do
      expect(text_and_number(helper.days_left_tag(-1, form: :short))).to eq([ "1日過ぎ", "1" ])
    end

    it "-1でストック詳細（long）なら、過ぎた日数を正の数にした長い文を返す" do
      expect(text_and_number(helper.days_left_tag(-1, form: :long))).to eq([ "目安を1日過ぎています", "1" ])
    end
  end
end
