ActiveAdmin.register Website do
  menu label: "Webサイト"

  permit_params :name, :url, :x_account_id, :active

  includes :x_account

  index do
    selectable_column
    id_column
    column :name
    column :url do |website|
      link_to website.url, website.url, target: "_blank", rel: "noopener"
    end
    column "X Account" do |website|
      if website.x_account
        auto_link website.x_account, "@#{website.x_account.at_name}"
      end
    end
    column :active
    column :last_crawl_status
    column :last_crawled_at
    actions
  end

  show do
    attributes_table do
      row :public_uid
      row :name
      row :url do |website|
        link_to website.url, website.url, target: "_blank", rel: "noopener"
      end
      row "X Account" do |website|
        if website.x_account
          auto_link website.x_account, "@#{website.x_account.at_name} (#{website.x_account.display_name})"
        end
      end
      row :active
      row :last_crawl_status
      row :last_crawled_at
      row :last_crawl_message do |website|
        simple_format website.last_crawl_message if website.last_crawl_message.present?
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs "Webサイト" do
      f.input :name, label: "名前", hint: "例: 東京チェスクラブ"
      f.input :url, label: "URL", hint: "イベント情報が載っているページのURL（トップページ、または大会・例会一覧ページ）",
        input_html: { placeholder: "https://example.com/events" }
      f.input :x_account, label: "同じクラブのXアカウント", include_blank: "なし",
        collection: XAccount.order(:at_name).map { |account| [ "@#{account.at_name} (#{account.display_name})", account.id ] }
      f.input :active, label: "巡回する"
    end
    f.actions
  end

  filter :name
  filter :url
  filter :x_account, collection: -> { XAccount.order(:at_name).map { |account| [ "@#{account.at_name}", account.id ] } }
  filter :active
  filter :last_crawl_status, as: :select, collection: -> { Website.last_crawl_statuses.keys }
  filter :last_crawled_at

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end
  end
end
