ActiveAdmin.register XAccount do
  actions :all, except: %i[edit update]

  permit_params :at_name

  index do
    selectable_column
    id_column
    column :at_name do |account|
      link_to "@#{account.at_name}", "https://x.com/#{account.at_name}", target: "_blank", rel: "noopener"
    end
    column :display_name
    column :x_user_id
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :public_uid
      row :at_name do |account|
        link_to "@#{account.at_name}", "https://x.com/#{account.at_name}", target: "_blank", rel: "noopener"
      end
      row :display_name
      row :x_user_id
      row :profile_image_url do |account|
        if account.profile_image_url.present?
          image_tag account.profile_image_url, size: "48x48"
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Xアカウント" do
      f.input :at_name, label: "アカウント名", hint: "例: JapanChessFed（@ は省略可）", input_html: { placeholder: "JapanChessFed" }
    end
    f.actions
  end

  filter :at_name
  filter :display_name
  filter :created_at

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end

    def create
      result = ImportXAccount::AccountImporter.call(at_name: params[:x_account][:at_name])
      namespace = ActiveAdmin.application.default_namespace

      if result.status == :created
        redirect_to polymorphic_path([ namespace, result.account ]), notice: "@#{result.account.at_name} を追加しました"
      else
        redirect_to polymorphic_path([ namespace, XAccount ]), alert: "@#{result.at_name} は既に登録されています"
      end
    rescue ArgumentError, XApi::Error, ActiveRecord::RecordInvalid => e
      flash.now[:error] = "追加に失敗しました: #{e.message}"
      @x_account = XAccount.new(at_name: params.dig(:x_account, :at_name))
      render :new, status: :unprocessable_entity
    end
  end
end
