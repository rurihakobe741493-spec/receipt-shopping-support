# 確認・登録画面の値を受け取り、チェックした行を、購入記録としてまとめて保存する
class ReceiptRegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # 確認・登録画面の1行
  class Row
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :selected, :boolean
    attribute :receipt_name, :string
    attribute :item_id, :string

    # 項目の名前は、購入記録の訳を使う（item_id は「ストック」）
    def self.human_attribute_name(attribute, options = {})
      Purchase.human_attribute_name(attribute.to_s == "item_id" ? :item : attribute, options)
    end
  end

  attribute :purchased_on, :date

  attr_accessor :user
  attr_writer :rows

  validate :selected_rows_must_exist
  validate :purchases_must_be_valid

  # 項目の名前は、購入記録の訳を使う（ラベルとエラーの文の言葉を、購入記録とそろえるため）
  def self.human_attribute_name(attribute, options = {})
    Purchase.human_attribute_name(attribute, options)
  end

  # 読み取りの結果から、最初に表示するフォームを作る（行はすべてチェックした状態）
  def self.from_receipt(user:, purchased_on:, item_lines:)
    rows = item_lines.map { |item_line| Row.new(selected: true, receipt_name: item_line) }
    new(user:, purchased_on:, rows:)
  end

  def rows
    @rows || []
  end

  # fields_for :rows から送られる、番号をキーにしたハッシュを受け取る
  def rows_attributes=(attributes)
    @rows = attributes.values.map { |row_attributes| Row.new(row_attributes) }
  end

  # 「ストック」の選択肢（ログイン中のユーザーの品目、名前順）
  def items
    user.items.order(:name)
  end

  def save
    return false if invalid?

    ActiveRecord::Base.transaction do
      purchases.each(&:save!)
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey
    errors.add(:base, :save_failed)
    false
  end

  # 保存する（した）購入記録の数
  def purchases_count
    purchases.size
  end

  private

    def selected_rows
      rows.select(&:selected)
    end

    # チェックした行の購入記録。品目はログイン中のユーザーの品目からだけ探す
    # （"" や "new"、ほかのユーザーの品目の id は見つからず nil になり、ストックの必須で止まる）
    def purchases
      @purchases ||= begin
        items = user.items.where(id: selected_rows.map(&:item_id)).index_by { |item| item.id.to_s }
        selected_rows.map do |row|
          Purchase.new(item: items[row.item_id], purchased_on:, receipt_name: row.receipt_name)
        end
      end
    end

    def selected_rows_must_exist
      errors.add(:base, :no_selected_rows) if selected_rows.empty?
    end

    # 購入記録の検証のエラーを、購入日はフォームに、それ以外はその行に移す
    def purchases_must_be_valid
      rows.each { |row| row.errors.clear }

      selected_rows.zip(purchases).each do |row, purchase|
        next if purchase.valid?

        purchase.errors.each do |error|
          case error.attribute
          when :purchased_on
            # 購入日はどの行も同じなので、エラーはフォームに1つだけ
            errors.import(error) unless errors.include?(:purchased_on)
          when :item
            row.errors.import(error, attribute: :item_id)
          else
            row.errors.import(error)
          end
        end
      end

      # 行にエラーがあれば、フォームも無効にする（validates_associated と同じ形。この文は画面には出さない）
      errors.add(:rows, :invalid) if rows.any? { |row| row.errors.any? }
    end
end
