require "rails_helper"

RSpec.describe User, type: :model do
  it "ファクトリーのデータは有効" do
    expect(build(:user)).to be_valid
  end

  describe "メールアドレス" do
    it "空なら無効" do
      user = build(:user, email: "")
      user.valid?
      expect(user.errors).to be_of_kind(:email, :blank)
    end

    it "登録済みと同じなら無効" do
      create(:user, email: "user@example.com")
      user = build(:user, email: "user@example.com")
      user.valid?
      expect(user.errors).to be_of_kind(:email, :taken)
    end

    it "大文字・小文字だけ違っても、登録済みなら無効" do
      create(:user, email: "user@example.com")
      user = build(:user, email: "USER@EXAMPLE.COM")
      user.valid?
      expect(user.errors).to be_of_kind(:email, :taken)
    end

   it "小文字にして保存する" do
      user = create(:user, email: "User@Example.com")
      expect(user.reload.email).to eq("user@example.com")
    end

    it "前後の空白を除いて保存する" do
      user = create(:user, email: " user@example.com ")
      expect(user.reload.email).to eq("user@example.com")
    end

    it "形が違えば無効（@ がない）" do
      user = build(:user, email: "userexample.com")
      user.valid?
      expect(user.errors).to be_of_kind(:email, :invalid)
    end
  end

  describe "パスワード" do
    it "空なら無効" do
      user = build(:user, password: "")
      user.valid?
      expect(user.errors).to be_of_kind(:password, :blank)
    end

    it "7文字なら無効" do
      user = build(:user, password: "a" * 7)
      user.valid?
      expect(user.errors).to be_of_kind(:password, :too_short)
    end

    it "8文字なら有効" do
      expect(build(:user, password: "a" * 8)).to be_valid
    end

    it "128文字なら有効" do
      expect(build(:user, password: "a" * 128)).to be_valid
    end

    it "129文字なら無効" do
      expect(build(:user, password: "a" * 129)).to be_invalid
    end

    it "確認用と一致しなければ無効" do
      user = build(:user, password_confirmation: "different123")
      user.valid?
      expect(user.errors).to be_of_kind(:password_confirmation, :confirmation)
    end
  end
end
