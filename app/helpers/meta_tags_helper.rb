module MetaTagsHelper
  SITE_NAME = "チェスイベントマップ"
  DEFAULT_DESCRIPTION = "チェスイベントを地図で探せるサービス"

  def meta_title_tag(title)
    tag.title(title)
  end

  def meta_description_tag(description)
    tag.meta(name: "description", content: description)
  end

  def meta_ogp_tags(title:, description:, url: nil, image: nil, type: "website", site_name: SITE_NAME)
    url ||= request.original_url
    image ||= default_og_image_url

    safe_join([
      tag.meta(property: "og:title", content: title),
      tag.meta(property: "og:description", content: description),
      tag.meta(property: "og:type", content: type),
      tag.meta(property: "og:url", content: url),
      tag.meta(property: "og:image", content: image),
      tag.meta(property: "og:site_name", content: site_name),
      tag.meta(name: "twitter:card", content: "summary_large_image"),
      tag.meta(name: "twitter:title", content: title),
      tag.meta(name: "twitter:description", content: description),
      tag.meta(name: "twitter:image", content: image)
    ], "\n")
  end

  def meta_canonical_tag(url)
    tag.link(rel: "canonical", href: url)
  end

  def default_meta_title_tag
    meta_title_tag(SITE_NAME)
  end

  def default_meta_description_tag
    meta_description_tag(DEFAULT_DESCRIPTION)
  end

  def default_meta_ogp_tags
    meta_ogp_tags(
      title: SITE_NAME,
      description: DEFAULT_DESCRIPTION,
      url: root_url
    )
  end

  private

  def default_og_image_url
    "#{request.base_url}/icon.png"
  end
end
