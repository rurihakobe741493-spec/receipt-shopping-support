# レシートの全文（ReceiptOcrService.call の戻り値）から、確認・登録画面の候補を取り出す
class ReceiptTextParser
  DATE_PATTERN = /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/
  MAX_AGE = 1.year

  def initialize(text)
    @lines = text.lines(chomp: true)
  end

  def purchased_on
    index = date_line_index
    return if index.nil?

    date = build_date(@lines[index].match(DATE_PATTERN))
    return if date.nil?

    today = Date.current
    date if date > today - MAX_AGE && date <= today
  end

  private
    def date_line_index
      @lines.index { |line| line.match?(DATE_PATTERN) }
    end

    def build_date(match)
      year, month, day = match.captures.map(&:to_i)
      Date.new(year, month, day) if Date.valid_date?(year, month, day)
    end
end
