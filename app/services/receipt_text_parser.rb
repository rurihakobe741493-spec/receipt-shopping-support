# レシートの全文（ReceiptOcrService.call の戻り値）から、確認・登録画面の候補を取り出す
class ReceiptTextParser
  DATE_PATTERNS = [
    /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/, # 2026年1月2日
    %r{(\d{4}|\d{2})/(\d{1,2})/(\d{1,2})}           # 2026/01/02・26/01/02
  ].freeze

  # 品目行の範囲の終わりの目印（文字の間の空白を許す）
  SUBTOTAL_PATTERN = /小\s*計/
  TOTAL_PATTERN = /合\s*計/
  # 小計も合計も読めなかったときの、範囲の終わりの目印
  FALLBACK_END_PATTERNS = [
    /消費税/,            # (内消費税
    /\d+\s*点(?!\p{L})/  # ( 3点)・1点
  ].freeze

  # 金額（¥ を \ や # と読み違えたもの、カンマや空白の入ったものを含む）
  PRICE_PATTERN = /[¥\\#]\s*\d(?:[\d,\s]*\d)?/

  # 品目ではない行
  EXCLUDED_LINE_PATTERNS = [
    TOTAL_PATTERN,                                          # 範囲の中の合計
    /\A\(?(?:\d+個\s*)?#{PRICE_PATTERN}(?:\s*\d+個)?\)?\z/, # 金額だけ・金額と個数だけ（¥100・¥100 2個・(2個¥200・¥10)）
    /\A\d(?:[\d,\s]*\d)?\z/,                                # 数字だけ（金額・個数・JANコード）
    /\A\d+\s*[個コ]\s*[x×]/,                                # 数量（2コ x 単100）
    /\A#{PRICE_PATTERN}\s*[x×]\s*\d/,                       # 数量（¥100×2(外10)）
    /\A@\s*\d/,                                             # 単価（@100 1）
    /割引/,                                                 # 割引
    /\A-/,                                                  # 値引き（-\10）
    /まとめ/,                                               # まとめ買い
    /税/,                                                   # 税（外税・内税の説明など）
    /\A[^\p{L}\p{N}]+\z/                                    # 文字も数字もない行（) など）
  ].freeze

  # 行の頭の書き方（内・内*・03x・11 ×・A11 ×・01* など）
  LINE_HEAD_PATTERN = /\A(?:内(?:\*|(?!\p{L}))|[A-Z]?\d{2}\s*[x×*])/
  # 行の末尾の金額
  TRAILING_PRICE_PATTERN = /\s*#{PRICE_PATTERN}\z/

  def initialize(text)
    @lines = text.lines(chomp: true)
  end

  def purchased_on
    index = date_line_index
    return if index.nil?

    date = build_date(date_match(@lines[index]))
    return if date.nil?

    date if Purchase.purchased_on_range.cover?(date)
  end

  def item_lines
    range_lines
      .reject { |line| excluded?(line) }
      .map { |line| line.sub(LINE_HEAD_PATTERN, "").sub(TRAILING_PRICE_PATTERN, "").squish }
      .reject(&:empty?)
  end

  private
    def date_line_index
      @lines.index { |line| date_match(line) }
    end

    # 行に合う最初の日付の形の結果を返す。どの形にも合わなければ nil
    def date_match(line)
      DATE_PATTERNS.each do |pattern|
        match = line.match(pattern)
        return match if match
      end
      nil
    end

    def build_date(match)
      year, month, day = match.captures.map(&:to_i)
      year += 2000 if year < 100
      Date.new(year, month, day) if Date.valid_date?(year, month, day)
    end

    # 日付の行の次（なければ先頭）から、範囲の終わりの前までの行を、整えて返す
    def range_lines
      index = date_line_index
      start = index ? index + 1 : 0
      lines = @lines[start..].map(&:squish)
      lines.take(range_end(lines))
    end

    # 最初の小計の行の位置。なければ最初の合計の行の位置。どちらもなければ最後まで
    def range_end(lines)
      lines.index { |line| line.match?(SUBTOTAL_PATTERN) } ||
        lines.index { |line| line.match?(TOTAL_PATTERN) } ||
        lines.index { |line| FALLBACK_END_PATTERNS.any? { |pattern| line.match?(pattern) } } ||
        lines.size
    end

    def excluded?(line)
      EXCLUDED_LINE_PATTERNS.any? { |pattern| line.match?(pattern) }
    end
end
