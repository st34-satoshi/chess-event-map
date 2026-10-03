ActiveAdmin.register Event do
  permit_params :title, :held_on, :url, :x_post_url, :place_id

  preserve_default_filters!
  remove_filter :x_publications
  filter :x_post_url_present, as: :select, label: "X post url の有無",
    collection: [ [ "空でない", true ], [ "空", false ] ]

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :title
      f.input :held_on
      f.input :place
      f.input :url
      f.input :x_post_url
    end
    f.actions
  end

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end
  end
end
