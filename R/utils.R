from_json <- function(url, ...) {
  jsonlite::fromJSON(
    url, 
    ..., 
    simplifyVector = FALSE, 
    flatten = FALSE
  )
}

# Get base portal API url
get_portal_url <- function(portal, endpoint){
  stopifnot(portal %in% portals()$portals)
  paste0(get_base_url(portal), "/api/", endpoint, "/1.0/")
}

# Search for datasets on a portal
search_datasets <- function(
  portal, 
  nrows = NULL, 
  refine = NULL, 
  exclude = NULL, 
  sort = NULL, 
  q = NULL, 
  lang = NULL
) {
  url <- get_portal_url(portal, "datasets") %>%
    paste0("search/") %>%
    add_parameters_to_url(
      nrows = nrows, 
      refine = refine, 
      exclude = exclude, 
      sort = sort, 
      q = q, 
      lang = lang
    )
  list(
    data = from_json(url),
    url = url
  )
}

# Get dataset meta data
get_dataset <- function(portal, id) {
  url <- get_portal_url(portal, "datasets") %>%
    paste0(id, "/")
  list(
    data = from_json(url),
    url = url
  )
}

get_facets <- function(fields){
  lapply(fields, function(field) {
    if (!"annotations" %in% names(field)) return(NULL) else {
      annotations <- field$annotations
      res <- lapply(annotations, function(annotation) {
        annotation$name == "facet"
      }) %>%
        unlist() %>%
        any()
      if (res) field$name else NULL
    }
  }) %>% unlist()
}

get_sortables <- function(fields){
  lapply(fields, function(field) {
    if (field$type == "int") field$name else NULL
  }) %>% unlist()
}

# Transform Polygon elements in the geo_shape column
tidy_polygon <- function(x) {
  y <- x[[1]] %>% 
    purrr::transpose()
  if (requireNamespace("sf", quietly = TRUE)) {
    mat <- matrix(unlist(y), ncol = 2)
    colnames(mat) <- c("lng", "lat")
    sf::st_polygon(list(mat))
  } else {
    tibble::tibble(
      lng = unlist(y[[1]]),
      lat = unlist(y[[2]])
    ) 
  }
}

# Transform MultiPolygon elements in the geo_shape column
tidy_multipolygon <- function(x) {
  y <- lapply(x, function(xx) purrr::transpose(xx[[1]]))
  if (requireNamespace("sf", quietly = TRUE)) {
    mat <- lapply(y, function(yy) {
      res <- matrix(unlist(yy), ncol = 2)
      colnames(res) <- c("lng", "lat")
      res
    })
    sf::st_polygon(mat)
  } else {
    lapply(y, function(yy) {
      tibble::tibble(
        lng = unlist(yy[[1]]),
        lat = unlist(yy[[2]])
      ) 
    })
  }
}

# Transform LineString elements in the geo_shape column
tidy_line_string <- function(x) {
  y <- x %>% 
    purrr::transpose()
  if (requireNamespace("sf", quietly = TRUE)) {
    x <- matrix(unlist(y), ncol = 2)
    colnames(x) <- c("lng", "lat")
    sf::st_linestring(x)
  } else {
    tibble::tibble(
      lng = unlist(y[[1]]),
      lat = unlist(y[[2]])
    )
  }
}

# Transform LineString elements in the geo_shape column
tidy_multiline_string <- function(x) {
  y <- lapply(x, function(xx) purrr::transpose(xx))
  if (requireNamespace("sf", quietly = TRUE)) {
    mat <- lapply(y, function(yy) {
      res <- matrix(unlist(yy), ncol = 2)
      colnames(res) <- c("lng", "lat")
      res
    })
    sf::st_multilinestring(list(mat))
  } else {
    lapply(y, function(yy) {
      tibble::tibble(
        lng = unlist(yy[[1]]),
        lat = unlist(yy[[2]])
      ) 
    })
  }
}

# Add additional parameters to the url
add_parameters_to_url <- function(
  url, 
  nrows = NULL, 
  refine = NULL, 
  exclude = NULL, 
  sort = NULL, 
  q = NULL,
  lang = NULL, 
  geofilter.distance = NULL, 
  geofilter.polygon = NULL, 
  format = NULL,
  callback = NULL,
  debug = FALSE, 
  ...
) {
  if (
    all(
      is.null(nrows),
      is.null(refine),
      is.null(exclude),
      is.null(sort),
      is.null(q),
      is.null(lang),
      is.null(geofilter.distance),
      is.null(geofilter.polygon),
      is.null(format),
      is.null(callback)
    )
  ) return(url) else additional_url <- c()
  
  # Handle nrows
  if (!is.null(nrows)) additional_url <- c(additional_url, rows = nrows)
  
  # Handle refine
  if (!is.null(refine)) for (i in seq_along(refine)) {
    facet <- names(refine)[i]
    val <- refine[[i]]
    names(val) <- paste0("refine.", facet)
    additional_url <- c(additional_url, facet = facet, val)
  }
  
  # Handle exclude
  if (!is.null(exclude)) for (i in seq_along(exclude)) {
    facet <- names(exclude)[i]
    val <- exclude[[i]]
    names(val) <- paste0("exclude.", facet)
    additional_url <- c(additional_url, facet = facet, val)
  }
  
  # Handle sort
  if (!is.null(sort)) additional_url <- c(additional_url, sort = sort)
  
  # Handle q
  if (!is.null(q)) additional_url <- c(additional_url, q = q)
  
  # Handle geofilter.distance
  if (!is.null(geofilter.distance)) additional_url <- c(
    additional_url, 
    geofilter.distance = toString(geofilter.distance)
  )
  
  # Handle geofilter.polygon
  if (!is.null(geofilter.polygon)) {
    geofilter.polygon <- 
      tidyr::unite(geofilter.polygon, polygon, lat, lon, sep = ",") %>%
      dplyr::mutate(polygon = paste0("(", polygon, ")")) %$% 
      polygon %>%
      toString()
    additional_url <- c(
      additional_url, 
      geofilter.polygon = geofilter.polygon
    )
  }
  
  # Handle format 
  if (!is.null(format)) additional_url <- c(additional_url, format = format)
  
  sep <- if (grepl("?", url, fixed = TRUE)) "&" else "?"
  url <- paste0(
    url, 
    sep, 
    paste(
      names(additional_url), 
      additional_url, 
      sep = "=", 
      collapse = "&")
  )
  if (debug) print(url)
  url
}

clean_list <- function(l) {
  l[!vapply(l, is.null, logical(1))]
}


get_base_url <- function(portal){
  (portals() %>%
     dplyr::filter(portals == portal)
  )$base_urls
}

# Constants -------------------------------------------------------------------------------------------------------

portals <- function(){
  tibble::tibble(
    name = c(
      "RATP",
      "R\u00E9gion Ile-de-France",
      "Infogreffe",
      "Toulouse M\u00E9tropole",
      "STAR",
      "Issy-les-Moulineaux",
      "STIF",
      "Paris",
      "Tourisme Alpes-Maritimes",
      "Tourisme Pas-de-Calais",
      "D\u00E9partement des Hauts-de-Seine",
      "Minist\u00E8re de l'Education Nationale, de l'Enseignement sup\u00E9rieur et de la Recherche",
      "ERDF",
      "RTE",
      "OpenDataSoft Public",
      "Nantes M\u00E9tropole"
    ),
    portals = c(
      "ratp",
      "iledefrance",
      "infogreffe",
      "toulouse",
      "star",
      "issy",
      "stif",
      "paris",
      "04",
      "62",
      "92",
      "enesr",
      "erdf", 
      "rte",
      "ods",
      "nantesmetropole"
    ),
    base_urls = c(
      "http://data.ratp.fr",
      "http://data.iledefrance.fr",
      "http://datainfogreffe.fr",
      "https://data.toulouse.fr",
      "https://data.explore.star.fr",
      "http://data.issy.com",
      "http://opendata.stif.info",
      "http://opendata.paris.fr",
      "http://tourisme04.opendatasoft.com",
      "http://tourisme62.opendatasoft.com",
      "https://opendata.hauts-de-seine.fr",
      "http://data.enseignementsup-recherche.gouv.fr",
      "https://data.erdf.fr", 
      "https://opendata.rte-france.com",
      "https://public.opendatasoft.com",
      "https://data.nantesmetropole.fr"
    )
  )
}

datasets_facets <- function(){
  c("modified",
    "published",
    "issued",
    "accrualperiodicity",
    "language",
    "license",
    "granularity",
    "dataquality",
    "theme",
    "keyword",
    "created",
    "creator",
    "contributor")
}

datasets_sortables <- function(){
  c("modified",
    "issued",
    "created")
}

MAX_API_RECORDS <- 10000
