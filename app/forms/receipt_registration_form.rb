# 確認・登録画面の値を受け取り、チェックした行を、購入記録としてまとめて保存する
# （「新規として登録」の行は、先に品目を作り、その品目の購入記録にする）
class ReceiptRegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # 確認・登録画面の1行
  class Row
    include ActiveModel::Model
    include ActiveModel::Attributes

    # 「ストック」の「新規として登録」の値
    NEW_ITEM_ID = "new"

    attribute :selected, :boolean
    attribute :receipt_name, :string
    attribute :item_id, :string
    # 品目名と周期は、「新規として登録」の行でだけ使う
    attribute :name, :string
    # 周期は型を付けず、送られた文字列のまま品目に渡す（"1.5" が 1 に丸められて、品目の検証を通らないように）
    attribute :cycle_days, default: -> { Item.column_defaults["cycle_days"] }

    # 項目の名前は、購入記録の訳を使う（item_id は「ストック」）。品目名と周期は、品目の訳を使う
    def self.human_attribute_name(attribute, options = {})
      case attribute.to_s
      when "name", "cycle_days" then Item.human_attribute_name(attribute, options)
      when "item_id" then Purchase.human_attribute_name(:item, options)
      else Purchase.human_attribute_name(attribute, options)
      end
    end

    def new_item?
      item_id == NEW_ITEM_ID
    end
  end

  attribute :purchased_on, :date

  attr_accessor :user
  attr_writer :rows

  validate :selected_rows_must_exist
  validate :rows_must_be_valid

  # 項目の名前は、購入記録の訳を使う（ラベルとエラーの文の言葉を、購入記録とそろえるため）
  def self.human_attribute_name(attribute, options = {})
    Purchase.human_attribute_name(attribute, options)
  end

  # 読み取りの結果から、最初に表示するフォームを作る（行はすべてチェックした状態。品目名の初期値は行の文字列）
  def self.from_receipt(user:, purchased_on:, item_lines:)
    rows = item_lines.map { |item_line| Row.new(selected: true, receipt_name: item_line, name: item_line) }
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
      purchases.each do |purchase|
        # 新しい品目は、自分で save! する（belongs_to に任せると save（! なし）で保存され、失敗しても例外にならないため）
        purchase.item.save! if purchase.item.new_record?
        purchase.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotUnique
    errors.add(:base, :save_failed)
    false
  end

  # 保存する（した）購入記録の数
  def purchases_count
    purchases.size
  end

  # 新しく作る（作った）品目の数
  def new_items_count
    selected_rows.count(&:new_item?)
  end

  private

    def selected_rows
      rows.select(&:selected)
    end

    # チェックした行の購入記録。品目はログイン中のユーザーの品目から探す・作る
    # （"" やほかのユーザーの品目の id は見つからず nil になり、ストックの必須で止まる）
    def purchases
      @purchases ||= begin
        items = user.items.where(id: selected_rows.map(&:item_id)).index_by { |item| item.id.to_s }
        selected_rows.map do |row|
          item = row.new_item? ? user.items.build(name: row.name, cycle_days: row.cycle_days) : items[row.item_id]
          Purchase.new(item:, purchased_on:, receipt_name: row.receipt_name)
        end
      end
    end

    def selected_rows_must_exist
      errors.add(:base, :no_selected_rows) if selected_rows.empty?
    end

    # 新しい品目と購入記録の検証のエラーを、購入日はフォームに、それ以外はその行に移す
    def rows_must_be_valid
      rows.each { |row| row.errors.clear }

      selected_rows.zip(purchases).each do |row, purchase|
        import_item_errors(row, purchase.item) if row.new_item? && purchase.item.invalid?

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

      add_same_name_errors

      # 行にエラーがあれば、フォームも無効にする（validates_associated と同じ形。この文は画面には出さない）
      errors.add(:rows, :invalid) if rows.any? { |row| row.errors.any? }
    end

    # 新しい品目のエラーを、行の同じ項目（品目名・周期）に移す
    # 登録済みの品目と同じ名前は、ストックから選ぶよう案内する文に付け替える（品目の文は、ストック詳細の編集でも使うため）
    def import_item_errors(row, item)
      item.errors.each do |error|
        if error.attribute == :name && error.type == :taken
          row.errors.add(:name, :same_as_registered_item)
        else
          row.errors.import(error)
        end
      end
    end

    # 新規の行どうしで、整えたあとの品目名が同じなら、その行すべてに文を出す
    # （品目の検証は保存済みの品目としか比べないため。登録済みの品目と同じ行は、そちらの文だけにする）
    def add_same_name_errors
      selected_rows.select(&:new_item?).group_by { |row| Item.normalize_value_for(:name, row.name) }.each do |name, same_rows|
        next if name.blank? || same_rows.size < 2

        same_rows.each do |row|
          row.errors.add(:name, :same_as_other_new_row) unless row.errors.include?(:name)
        end
      end
    end
end
