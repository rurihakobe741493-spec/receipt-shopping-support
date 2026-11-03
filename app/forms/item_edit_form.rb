# ストック詳細の編集の値を受け取り、品目名と周期を保存する
# 周期は、画面に出していた周期と違うときだけ保存し、その日を変更日として残す
class ItemEditForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  # 周期は型を付けず、送られた文字列のまま品目に渡す（"1.5" が 1 に丸められて、品目の検証を通らないように）
  attribute :cycle_days
  # 画面に出していた周期（隠した欄）。届いた周期と比べて、周期を変えたかを決める
  attribute :displayed_cycle_days

  # 編集する品目（コントローラーが、ログイン中のユーザーの品目から探して渡す。送られた値からは取らない）
  attr_accessor :item

  validate :item_must_be_valid

  # 項目の名前は、品目の訳を使う（ラベルとエラーの文の言葉を、品目とそろえるため）
  def self.human_attribute_name(attribute, options = {})
    Item.human_attribute_name(attribute, options)
  end

  # 最初に表示するフォームを作る。周期の欄の初期値は、計算した周期（詳細に出している周期）
  def self.from_item(item)
    cycle_days = ConsumptionEstimate.new(item).cycle_days
    new(item:, name: item.name, cycle_days:, displayed_cycle_days: cycle_days)
  end

  # 周期を変えたか。保存値ではなく、画面に出していた周期と比べる（品目名だけ直したときに、変えた扱いにしないため）
  def cycle_changed?
    cycle_days.to_s != displayed_cycle_days.to_s
  end

  # 品目に値を入れてから検証し、保存する
  def save
    assign_to_item
    return false if invalid?

    item.save!
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    # 検証のあとに、同じ名前がほかで保存されたとき（2つのタブで同時に保存したときなど）。品目名の重複と同じ文を出す
    item.errors.add(:name, :taken) unless item.errors.of_kind?(:name, :taken)
    import_item_errors
    false
  end

  private

    # 品目名はいつも、周期は変えたときだけ品目に入れる（変えたときは、今日を変更日にする）
    def assign_to_item
      item.name = name
      return unless cycle_changed?

      item.cycle_days = cycle_days
      item.cycle_changed_on = Date.current
    end

    def item_must_be_valid
      import_item_errors if item.invalid?
    end

    # 品目のエラーを、フォームの同じ項目（品目名・周期）に移す（文は品目の訳から作られる）
    def import_item_errors
      item.errors.each { |error| errors.import(error) }
    end
end
