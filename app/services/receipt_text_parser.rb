# レシートの全文（ReceiptOcrService.call の戻り値）から、確認・登録画面の候補を取り出す
class ReceiptTextParser
  DATE_PATTERNS = [
    /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/, # 2026年1月2日
    %r{(\d{4}|\d{2})/(\d{1,2})/(\d{1,2})}           # 2026/01/02・26/01/02
  ].freeze
  MAX_AGE = 1.year

  def initialize(text)
    @lines = text.lines(chomp: true)
  end

  def purchased_on
    index = date_line_index
    return if index.nil?

    date = build_date(date_match(@lines[index]))
    return if date.nil?

    today = Date.current
    date if date > today - MAX_AGE && date <= today
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
end
