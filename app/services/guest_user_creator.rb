# ゲストでログインするときに、新しいゲストを見本の3品目付きで作る
# 作る前に、残しておく時間（User::GUEST_LIFETIME）を過ぎたゲストを品目ごと消す
class GuestUserCreator
  # 見本の品目。購入日は今日から何日前かで持つ（いつ作っても同じ状態になるように）
  SAMPLE_ITEMS = [
    # 周期20日・目安を10日過ぎ
    { name: "トイレットペーパー", receipt_name: "トイレットペーパー12R", days_ago: [ 50, 30 ] },
    # 周期25日・あと5日
    { name: "洗濯洗剤", receipt_name: "洗濯洗剤 詰替", days_ago: [ 45, 20 ] },
    # 周期30日・あと25日
    { name: "歯みがき粉", receipt_name: "ハミガキ 120g", days_ago: [ 35, 5 ] }
  ].freeze

  def self.call
    new.call
  end

  def call
    # 1件ずつ destroy するので、品目と購入記録も消える（dependent: :destroy）
    User.expired_guests.find_each(&:destroy)

    ActiveRecord::Base.transaction do
      user = User.create!(
        email: "guest-#{SecureRandom.uuid}@example.com",
        password: Devise.friendly_token,
        guest: true
      )
      create_sample_items(user)
      user
    end
  end

  private

    def create_sample_items(user)
      today = Date.current
      SAMPLE_ITEMS.each do |sample|
        item = user.items.create!(name: sample[:name])
        sample[:days_ago].each do |days|
          item.purchases.create!(purchased_on: today - days, receipt_name: sample[:receipt_name])
        end
      end
    end
end
