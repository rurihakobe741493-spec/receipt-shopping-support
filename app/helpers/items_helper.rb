module ItemsHelper
  # 残り日数の文を、数字（今日が目安のときは「今日」）だけ大きくして返す
  # form: :short はトップのカード（目安を過ぎたら「〇日過ぎ」）、:long はストック詳細（「目安を〇日過ぎています」）
  # 数字の span は html_safe なので、_html の訳に差し込んでもエスケープされない（ActiveSupport::HtmlSafeTranslation）
  # ヘルパーは、呼んだビューの場所で訳を探すので、キーは頭から書く
  def days_left_tag(days_left, form:)
    number_class = form == :long ? "text-3xl font-bold" : "text-2xl font-bold"

    if days_left.positive?
      t("items.days_left.remaining_html", number: tag.span(days_left, class: number_class))
    elsif days_left.zero?
      t("items.days_left.today_html", number: tag.span(t("items.days_left.today_number"), class: number_class))
    else
      key = form == :long ? "items.days_left.overdue_html" : "items.days_left.overdue_short_html"
      t(key, number: tag.span(-days_left, class: number_class))
    end
  end
end
