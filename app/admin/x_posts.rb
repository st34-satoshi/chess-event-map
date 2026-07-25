ActiveAdmin.register XPost do
  actions :all, except: %i[new create destroy]

  permit_params :event_detection_status, :text, :url, :posted_at

  includes :x_account

  index do
    selectable_column
    id_column
    column :x_account do |post|
      auto_link post.x_account, "@#{post.x_account.at_name}"
    end
    column "Display name" do |post|
      post.x_account.display_name
    end
    column :text do |post|
      truncate(post.text, length: 80)
    end
    column :event_detection_status
    column :posted_at
    column :url do |post|
      if post.url.present?
        link_to "X", post.url, target: "_blank", rel: "noopener"
      end
    end
    actions
  end

  show do
    attributes_table do
      row :public_uid
      row :x_account do |post|
        auto_link post.x_account, "@#{post.x_account.at_name}"
      end
      row "Display name" do |post|
        post.x_account.display_name
      end
      row :x_post_id
      row :text do |post|
        simple_format post.text
      end
      row :event_detection_status
      row :posted_at
      row :url do |post|
        if post.url.present?
          link_to post.url, post.url, target: "_blank", rel: "noopener"
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      li do
        label "X Account", class: "label"
        div "@#{f.object.x_account.at_name} (#{f.object.x_account.display_name})"
      end
      li do
        label "X Post ID", class: "label"
        div f.object.x_post_id
      end
      f.input :event_detection_status, as: :select, collection: XPost.event_detection_statuses.keys
      f.input :text, as: :text
      f.input :url
      f.input :posted_at, as: :datetime_select
    end
    f.actions
  end

  filter :x_account, collection: -> { XAccount.order(:at_name) }
  filter :event_detection_status, as: :select, collection: XPost.event_detection_statuses.keys
  filter :text
  filter :posted_at
  filter :created_at

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end
  end
end
