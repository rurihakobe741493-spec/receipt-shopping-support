module ItemsHelper
  # 残り日数の文。0は今日が目安、マイナスは目安を過ぎた日数（ストック詳細でも使う）
  # ヘルパーは、呼んだビューの場所で訳を探すので、キーは頭から書く
  def days_left_text(days_left)
    if days_left.positive?
      t("items.days_left.remaining", count: days_left)
    elsif days_left.zero?
      t("items.days_left.today")
    else
      t("items.days_left.overdue", count: -days_left)
    end
  end
end
