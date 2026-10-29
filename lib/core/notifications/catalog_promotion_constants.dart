/// Canonical catalog tag for featured / promoted tool listings and discovery polling.
///
/// Admins add this tag in the catalog; [GET /v1/plugins?tag=promoted] returns matching tools.
class CatalogPromotionConstants {
  const CatalogPromotionConstants._();

  static const String promotionTag = 'promoted';
}
