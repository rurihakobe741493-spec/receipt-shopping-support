require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "新規登録の画面を表示し、ヘッダーにはログインのリンクだけを出す" do
      get new_user_registration_path

      expect(response).to have_http_status(200)
      expect(response.body).to have_field("user[email]")
      expect(response.body).to have_field("user[password]")
      expect(response.body).to have_field("user[password_confirmation]")
      expect(response.body).to have_css("header a[href='#{new_user_session_path}']")
      expect(response.body).not_to have_css("header a[href='#{new_user_registration_path}']")
    end
  end

  describe "POST /users" do
    it "正しく入力すると、ユーザーを作り、ログインした状態でトップへ戻す" do
      expect { post user_registration_path, params: { user: attributes_for(:user) } }.to change(User, :count).by(1)

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("devise.registrations.signed_up"))

      follow_redirect!
      expect(response.body).to have_css("form[action='#{receipt_scans_path}']")
    end

    it "メールアドレスが空なら、422 で描き直し、ヘッダーには新規登録のリンクを出さない" do
      expect { post user_registration_path, params: { user: attributes_for(:user, email: "") } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("メールアドレスを入力してください")
      expect(response.body).not_to have_css("header a[href='#{new_user_registration_path}']")
    end

    it "パスワードが7文字なら、422 で描き直す" do
      expect { post user_registration_path, params: { user: attributes_for(:user, password: "a" * 7) } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワードは8文字以上で入力してください")
    end

    it "確認のパスワードが一致しないなら、422 で描き直す" do
      expect { post user_registration_path, params: { user: attributes_for(:user, password_confirmation: "different123") } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワード（確認）とパスワードの入力が一致しません")
    end

    it "登録済みのメールアドレス（大文字違い）なら、422 で描き直す" do
      create(:user, email: "taken@example.com")

      expect { post user_registration_path, params: { user: attributes_for(:user, email: "TAKEN@example.com") } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("メールアドレスはすでに存在します")
    end
  end

  describe "GET /users/edit" do
    it "ログインしていれば、アカウント設定の画面を表示する" do
      sign_in create(:user)
      get edit_user_registration_path

      expect(response).to have_http_status(200)
      expect(response.body).to have_css("h1", text: I18n.t("devise.registrations.edit.title"))
      expect(response.body).to have_css("input[name='user[email]'][autocomplete='email']")
      expect(response.body).to have_css("input[name='user[password]'][autocomplete='new-password'][aria-describedby='user_password_note']")
      expect(response.body).to have_css("#user_password_note", text: I18n.t("devise.registrations.edit.password_note"))
      expect(response.body).to have_css("input[name='user[password_confirmation]'][autocomplete='new-password']")
      expect(response.body).to have_css("input[name='user[current_password]'][autocomplete='current-password']")
      expect(response.body).to have_css("input[type='submit'][value='#{I18n.t("devise.registrations.edit.submit")}'][data-turbo-submits-with='#{I18n.t("devise.registrations.edit.submitting")}']")
    end

    it "退会のボタンを出さない" do
      sign_in create(:user)
      get edit_user_registration_path

      expect(response.body).not_to have_css("form[action='#{user_registration_path}'] input[name='_method'][value='delete']")
    end

    it "ヘッダーには、アカウント設定のリンクを出さず、ログアウトだけを出す" do
      sign_in create(:user)
      get edit_user_registration_path

      expect(response.body).not_to have_css("header a[href='#{edit_user_registration_path}']")
      expect(response.body).to have_css("header button", text: I18n.t("shared.header.sign_out"))
    end
  end

  describe "ほかの画面のヘッダー（ログインしている）" do
    it "トップには、アカウント設定のリンクとログアウトを出す" do
      sign_in create(:user)
      get root_path

      expect(response.body).to have_css("header a[href='#{edit_user_registration_path}']", text: I18n.t("shared.header.account"))
      expect(response.body).to have_css("header button", text: I18n.t("shared.header.sign_out"))
    end

    it "ストック詳細には、アカウント設定のリンクとログアウトを出す" do
      item = create(:item)
      sign_in item.user
      get item_path(item)

      expect(response.body).to have_css("header a[href='#{edit_user_registration_path}']", text: I18n.t("shared.header.account"))
      expect(response.body).to have_css("header button", text: I18n.t("shared.header.sign_out"))
    end
  end

  describe "PUT /users" do
    # 既定は「メールアドレスもパスワードも変えない」。変える項目だけを渡す
    def update_params(user, **attributes)
      { user: { email: user.email, password: "", password_confirmation: "", current_password: user.password }.merge(attributes) }
    end

    it "メールアドレスだけを変えると、トップへ戻し、知らせを出す" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, email: "changed@example.com")

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("devise.registrations.updated"))
      expect(user.reload.email).to eq("changed@example.com")
    end

    it "パスワードを変えると、新しいパスワードで照合でき、古いパスワードでは照合できない" do
      user = create(:user)
      old_password = user.password
      sign_in user
      put user_registration_path, params: update_params(user, password: "newpassword123", password_confirmation: "newpassword123")

      expect(response).to have_http_status(303)
      expect(user.reload.valid_password?("newpassword123")).to be(true)
      expect(user.valid_password?(old_password)).to be(false)
    end

    it "現在のパスワードが空なら、422 で描き直し、入れたメールアドレスを残し、保存しない" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, email: "changed@example.com", current_password: "")

      expect(response).to have_http_status(422)
      expect(response.body).to include("現在のパスワードを入力してください")
      expect(response.body).to have_field("user[email]", with: "changed@example.com")
      expect(user.reload.email).not_to eq("changed@example.com")
    end

    it "現在のパスワードが違うなら、422 で描き直す" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, current_password: "wrong-password")

      expect(response).to have_http_status(422)
      expect(response.body).to include("現在のパスワードが違います")
    end

    it "新しいパスワードが7文字なら、422 で描き直し、パスワードの欄を空にする" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, password: "a" * 7, password_confirmation: "a" * 7)

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワードは8文字以上で入力してください")
      expect(response.body).not_to have_css("input[type='password'][value]")
    end

    it "確認のパスワードが一致しないなら、422 で描き直す" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, password: "newpassword123", password_confirmation: "different123")

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワード（確認）とパスワードの入力が一致しません")
    end

    it "新しいパスワードを空にして確認だけを入れると、2つのエラーで 422 を返す" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, password_confirmation: "newpassword123")

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワードを入力してください")
      expect(response.body).to include("パスワード（確認）とパスワードの入力が一致しません")
    end

    it "描き直した画面のヘッダーには、アカウント設定のリンクを出さない" do
      user = create(:user)
      sign_in user
      put user_registration_path, params: update_params(user, current_password: "")

      expect(response.body).not_to have_css("header a[href='#{edit_user_registration_path}']")
    end
  end
end
